#https://docs.microsoft.com/en-us/azure/virtual-machines/linux/add-disk
sudo fdisk /dev/sdc
# n
# p
# <enter>
# <enter>
# <enter>
w

sudo mkfs -t ext4 /dev/sdc1
sudo mkdir /datadrive
sudo mount /dev/sdc1 /datadrive

sudo -i blkid