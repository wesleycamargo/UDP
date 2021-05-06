# Databricks notebook source
# MAGIC %md # Introduction

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC Implementation of a calculator class to demonstrate the unittest capabilites für Databricks notebooks. Published [here](https://databricks-prod-cloudfront.cloud.databricks.com/public/4027ec902e239c93eaaa8714f173bcfc/4113294248817247/1934597425527841/7111805527782941/latest.html)

# COMMAND ----------

# MAGIC %md # Calculator

# COMMAND ----------

class Calculator:

	def __init__(self, x = 10, y = 8):
		self.x = x
		self.y = y
		
	def add(self, x = None, y = None):
		if x == None: x = self.x
		if y == None: y = self.y			
          
		return x+y

	def subtract(self, x = None, y = None):
		if x == None: x = self.x
		if y == None: y = self.y	
          
		return x-y

	def multiply(self, x = None, y = None):
		if x == None: x = self.x
		if y == None: y = self.y			
          
		return x*y

	def divide(self, x = None, y = None):
		if x == None: x = self.x
		if y == None: y = self.y			
          
		if y == 0:
			raise ValueError('cannot divide by zero')
		else:
			return x/y

# COMMAND ----------

c = Calculator()
print(c.add(20, 10), c.subtract(20, 10), c.multiply(20, 10), c.divide(20, 10))