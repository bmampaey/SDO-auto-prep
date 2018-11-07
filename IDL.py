#!/usr/bin/python
import pexpect
import sys
import argparse
import signal
import os, os.path
import logging
from glob import glob
import Queue
import threading


class IDL:
	"""Run an IDL session and allow to run IDL commands in it"""
	# Maximal time for idl to start
	start_wait_time = 60
	
	# Maximal time to wait for idl to exit
	exit_wait_time = 60
	
	# Prompt
	prompt = "\nIDL>"
	
	errors = ["Execution halted"]
	
	def __init__(self, idl = "idl", logfile = None):
		self.idl = idl
		self.logfile = logfile
		self.session = None
	
	def __del__(self):
		self.stop()
	
	def start(self):
		'''Start an IDL session and wait for the IDL prompt'''
		# Maybe we have already started
		if self.started():
			return True
		
		# We try to start idl
		try:
			self.session = pexpect.spawn(self.idl, timeout=self.start_wait_time, logfile=self.logfile)
		except pexpect.ExceptionPexpect, why:
			logging.critical("Error starting idl: %s", str(why))
			self.stop()
			return False
		
		# We are all set
		return True
	
	def started(self):
		return self.session is not None and self.session.isalive()
	
	def stop(self):
		'''Stop an IDL session and make sure that the license is released'''
		if self.started():
			self.session.sendline("exit")
			try:
				self.session.expect(pexpect.EOF, timeout=self.exit_wait_time)
			except pexpect.TIMEOUT:
				# Because if we fail to terminate idl, it holds a license we make sure it is dead by killing it
				os.kill(-self.session.pid, signal.SIGKILL)
	
	def run(self, instruction, timeout = None):
		'''Run an IDL instruction, and wait for it to finish'''
		
		# We make sure idl is started
		if not self.start():
			logging.error("IDL is not started")
			return False
		
		# We need an IDL prompt
		if self.session.after != self.prompt:
			index = self.session.expect_exact([self.prompt, pexpect.EOF, pexpect.TIMEOUT], timeout=self.start_wait_time)
			if index == 0:
				logging.debug("OK, got an IDL prompt")
			elif index == 1:
				logging.critical("Didn't not receive an IDL prompt")
				self.stop()
				return False
			elif index == 2:
				logging.critical("Didn't not receive an IDL prompt in a timely fashion")
				self.stop()
				return False
			else:
				logging.critical("Don't know what happened.\nidl before: %s\nidl after: %s", self.session.before, self.session.after)
				self.stop()
				return False
		
		# We try to execute the instruction
		try:
			self.session.sendline(instruction)
			index = self.session.expect_exact(self.errors + [self.prompt], timeout = timeout)
		except pexpect.EOF:
			logging.error("Instruction %s terminated with unkown error. Recieved: %s", instruction, self.session.before)
			return False
		except pexpect.TIMEOUT:
			logging.error("Error, instruction %s didn't terminated in a timely fashion", instruction)
			return False
		else:
			if index < len(self.errors): # We got an error message
				logging.error("Error running instruction %s with error %s.\nRecieved: %s", instruction, self.session.after, self.session.before)
				return False
		
		# We are all good
		logging.debug("OK, instruction %s ran successfuly.", instruction)
		return True

class SSWIDL(IDL):
	"""Run an IDL session configured for SSW and allow to run IDL and SSW commands in it"""
	def __init__(self, csh = "/bin/csh", SSW_path = "/usr/local/ssw", SSWDB_path = "/usr/local/sswdb", SSW_instruments = [], logfile = None):
		self.csh = csh
		self.SSW_path = SSW_path
		self.SSWDB_path = SSWDB_path
		self.SSW_instruments = SSW_instruments
		self.logfile = logfile
		self.session = None
	
	def __run_csh(self, instruction, timeout = None):
		'''Run a csh instruction, and wait for it to finish'''
		
		# We try to execute the instruction
		try:
			self.session.sendline(instruction)
			self.session.expect("%", timeout = timeout)
		except pexpect.EOF:
			logging.error("Instruction %s terminated with unkown error. Recieved: %s", instruction, self.session.before)
			return False
		except pexpect.TIMEOUT:
			logging.error("Error, instruction %s didn't terminated in a timely fashion", instruction)
			return False
		
		# We are all good
		logging.debug("OK, instruction %s ran successfuly.", instruction)
		return True
	
	def start(self):
		'''Start an SSW IDL session and wait for the IDL prompt'''
		# Maybe we have already started
		if self.started():
			return True
		
		# We set up the environment variables
		if os.path.isdir(self.SSW_path):
			os.environ["SSW"] = self.SSW_path
		else:
			raise ValueError("SSW path is not a directory")
		
		if os.path.isdir(self.SSWDB_path):
			os.environ["SSWDB"] = self.SSWDB_path
			os.environ["SDB"] = self.SSWDB_path
		else:
			raise ValueError("SSWDB path is not a directory")
		
		os.environ["SSW_INSTR"] = " ".join(self.SSW_instruments)
		
		
		# We try to start a csh prompt
		try:
			self.session = pexpect.spawn(self.csh, timeout=self.start_wait_time, logfile=self.logfile)
		except pexpect.ExceptionPexpect, why:
			logging.critical("Error starting csh: %s", str(why))
			self.stop()
			return False
		
		# We source the SSW setup file
		self.__run_csh("source $SSW/gen/setup/setup.ssw", timeout=self.start_wait_time)
		self.__run_csh("exec `alias sswidl` nox", timeout=self.start_wait_time)
		
		return True
