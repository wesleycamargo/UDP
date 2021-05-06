# Databricks notebook source
# MAGIC %md # Introduction

# COMMAND ----------

# MAGIC %md
# MAGIC 
# MAGIC Implementation of a *calculator test class* to demonstrate the unittest capabilites für Databricks notebooks. Published [here](https://databricks-prod-cloudfront.cloud.databricks.com/public/4027ec902e239c93eaaa8714f173bcfc/4113294248817247/1934597425527846/7111805527782941/latest.html)

# COMMAND ----------

# MAGIC %md # Calculator Test

# COMMAND ----------

# MAGIC %run "./Calculator"

# COMMAND ----------

import unittest

class CalculatorTests(unittest.TestCase):
  
  @classmethod
  def setUpClass(cls):
    cls.app = Calculator()

  def setUp(self):
    # print("this is setup for every method")
    pass

  def test_add(self):
    self.assertEqual(self.app.add(10,5), 15, )

  def test_subtract(self):
    self.assertEqual(self.app.subtract(10,5), 5)
    self.assertNotEqual(self.app.subtract(10,2), 4)

  def test_multiply(self):
    self.assertEqual(self.app.multiply(10,5), 50)

  def tearDown(self):
    # print("teardown for every method")
    pass

  @classmethod
  def tearDownClass(cls):
    # print("this is teardown class")
    pass

# COMMAND ----------

suite =  unittest.TestLoader().loadTestsFromTestCase(CalculatorTests)
unittest.TextTestRunner(verbosity=2).run(suite)