# Pre-requisites
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common curl

# Grab the hashicorp common key for all their shit and add their repo.
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Now install the things
sudo apt-get update && sudo apt-get install nomad terraform vault consul packer
