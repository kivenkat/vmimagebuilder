sudo yum check-update WALinuxAgent
sudo yum install WALinuxAgent
sudo sed -i 's/# AutoUpdate.Enabled=n/AutoUpdate.Enabled=y/g' /etc/waagent.conf
sudo systemctl restart waagent.service
