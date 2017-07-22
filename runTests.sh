#!/bin/sh

/usr/local/pike/8.0.462/include/pike/mktestsuite testsuite.in >testsuite
pike -MMODULE -x test_pike testsuite
