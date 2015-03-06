#!/usr/bin/python
import sys
import argparse
import signal
import os, os.path
import logging
from glob import glob
import Queue
import threading
from IDL import SSWIDL
from datetime import datetime, timedelta

# Timeout in seconds to process one file
timeout = 120
# Number of threads
number_threads = 4
# The base directory of the input fits files
input_file_dir = "/data/SDO/public/1H_synoptic/aia.lev1"
# The pattern of the input filenames
input_file_pattern = "{wavelength:04d}/{year:04d}/{month:02d}/{day:02d}/*.fits"
# The base directory of the outpout fits files
output_file_dir = "/data/SDO/public/AIA_HMI_1H_synoptic/aia.lev1.prepped"
# The pattern of the output filenames
output_file_pattern = "{wavelength:04d}/{year:04d}/{month:02d}/{day:02d}/{filename}"
# The duration to process before now. Must be a timedelta
past_duration = timedelta(days=200)
# The wavelengths to process
wavelengths = [171,193]


def aia_prep(jobs, timeout = 120, verbose = False, force = False):
	''' aia_prep AIA fits files by running sswidl with pexpect '''
	
	# We setup the logging
	# Should be changed to use the logging facility
	if verbose:
		logfile = sys.stdout
	else:
		logfile = None
	
	# We try to start sswidl
	idl = SSWIDL(SSW_instruments = ["aia"], logfile=logfile)
	if not idl.start():
		return False
	
	# We construct the aia_prep command
	aia_prep_cmd = "aia_prep, '{filename}', 0, outdir = '{outdir}', outfile = '{outfile}', /do_write_fits"
	if verbose:
		aia_prep_cmd += ", /verbose"
	
	logging.debug("aia_prep command template: %s", aia_prep_cmd) 
	
	job = jobs.get()
	while job and not terminate_thread.is_set():
		# We make sure the file has not already been preprocessed
		if not force and os.path.exists(os.path.join(job['outdir'], job['outfile'])):
			logging.info("File %s was already aia_prepped, skipping.", job['filename'])
		else: # We run aia_prep
			logging.info("About to aia_prep file %s", job['filename'])
			idl.run(aia_prep_cmd.format(filename = job['filename'], outdir = job['outdir'], outfile = job['outfile']), timeout = timeout)
		
		job = jobs.get()
	
	idl.stop()
	
	logging.info("Stopping thread")

def terminate_gracefully(signal, frame):
	logging.info("Received signal %s: Stopping threads", str(signal))
	terminate_thread.set()

if __name__ == "__main__":
		
	# Get the arguments
	parser = argparse.ArgumentParser(description='Call the IDL aia_prep on AIA fits files')
	parser.add_argument('--debug', '-d', default=False, action='store_true', help='Debug output to screen')
	parser.add_argument('--verbose', '-v', default=False, action='store_true', help='Verbose output to screen')
	parser.add_argument('--force', '-f', default=False, action='store_true', help='Force to aia_prep files that have already been prepped')
	
	args = parser.parse_args()
	
	if args.debug:
		logging.basicConfig(level = logging.DEBUG, format='%(levelname)-8s: %(message)s')
		logging.root.handlers[0].setLevel(logging.DEBUG)
	elif args.verbose:
		logging.basicConfig(level = logging.INFO, format='%(levelname)-8s: %(message)s')
		logging.root.handlers[0].setLevel(logging.INFO)
	else:
		logging.basicConfig(level = logging.CRITICAL, format='%(levelname)-8s: %(message)s')
		logging.root.handlers[0].setLevel(logging.CRITICAL + 10)
	
	# The terminate_thread will tell threads to terminate gracefully
	terminate_thread = threading.Event()
	
	# We setup the termination signal
	signal.signal(signal.SIGINT, terminate_gracefully)
	signal.signal(signal.SIGQUIT, terminate_gracefully)
	signal.signal(signal.SIGTERM, terminate_gracefully)
	signal.signal(signal.SIGHUP, signal.SIG_IGN)
	
	jobs = Queue.Queue()
	
	# We start the threads
	threads = list()
	for t in range(number_threads):
		thread = threading.Thread(name="aia_prep_"+str(t), target=aia_prep, args=(jobs, timeout, args.verbose))
		thread.start()
		threads.append(thread)
	
	# We feed the filenames
	date = datetime.utcnow() - past_duration
	while date < datetime.utcnow():
		for wavelength in wavelengths:
			filenames = os.path.join(input_file_dir, input_file_pattern.format(year = date.year, month = date.month, day = date.day, hour = date.hour, wavelength = wavelength))
			logging.debug("Looking for files %s", filenames)
			filenames = glob(filenames)
			logging.debug("Found files %s", filenames)
			for filename in filenames:
				output_filename = output_file_pattern.format(year = date.year, month = date.month, day = date.day, hour = date.hour, wavelength = wavelength, filename = os.path.basename(filename))
				outdir, outfile = os.path.split(os.path.join(output_file_dir, output_filename))
				if not os.path.isdir(outdir):
					try:
						logging.info("Created directory %s", outdir)
						os.makedirs(outdir)
					except Exception, why:
						logging.error("Could not create output directory %s", outdir)
						continue
				jobs.put({"filename": filename, "outfile": outfile, "outdir": outdir})
		date += timedelta(hours=1)
	
	for thread in threads:
		jobs.put(None)


