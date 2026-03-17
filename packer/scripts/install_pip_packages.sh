#!/bin/bash
set -e

curl -sS https://bootstrap.pypa.io/get-pip.py | python3.11

# Install pip packages
python3.11 -m venv venv
source venv/bin/activate
pip install pyvmomi passlib netaddr git+https://github.com/vmware/vsphere-automation-sdk-python.git dnspython beautifulsoup4 jmespath requests
pip cache purge