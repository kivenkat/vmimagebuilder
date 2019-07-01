wget https://pypi.python.org/packages/source/s/setuptools/setuptools-7.0.tar.gz --no-check-certificate
tar xzf setuptools-7.0.tar.gz
cd setuptools-7.0
sudo python setup.py install
wget https://github.com/Azure/WALinuxAgent/archive/v2.2.36.zip
unzip v2.2.36.zip
cd WALinuxAgent-2.2.36
sudo systemctl restart waagent
