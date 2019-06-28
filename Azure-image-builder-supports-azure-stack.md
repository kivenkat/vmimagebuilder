# Azure Image Builder now supports Azure Stack

With the help on Azure Image Builder, you can now build an image for Azure and Azure Stack using a consistent pipeline. The use cases for Azure Image builder on Azure Stack are as follows:
1.	To prepare a custom image for Azure Stack/Azure, there are [various steps](https://docs.microsoft.com/en-us/azure/virtual-machines/linux/create-upload-generic) that need to be followed to create a base image upon which customizations are added. These can not only be time consuming but also can give way to human error. With Azure Image Builder, you can use an Azure platform image as the base to do further customizations; all this without having to set up your own image building pipeline. 
2.	Azure Image builder provides an easy and foolproof method for customers who want to bring RHEL BYOS images to Azure Stack.
3.	Using Azure Image builder to create these golden custom images allows for consistent images to be used across clouds (Azure and Azure Stack)

The idea here, is to create an image using the Azure Image builder service on the Azure which outputs a VHD. After this, you can transfer the VHD to a storage account on Azure Stack and spin up VMs from that VHD. Below are the steps laid out:

## Step 1: Use Azure Image Builder to distribute the image as a VHD on Azure
Azure Image Builder has various ways to output the finished image. We will use distribute the image as a VHD that can be transferred to a storage account on Azure Stack 

To distribute a customized Linux image to VHD, you may use [this quickstart](https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts/4_Creating_a_Custom_Linux_Image_to_VHD) as an example. You can use this as a sample to distribute a Windows Image to VHD as well. 

Let’s take the example of using Azure Image Builder to create a RHEL BYOS image that can be used for Azure Stack. I have used [this quickstart](https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts/6_Creating_a_Custom_Image_using_Red_Hat_Subscription_Licences_to_VHD) as an example for guidance. Prior to doing the commands below, make sure that your Azure subscription is registered for the preview.

```
# setting environment variables
# destination image resource group
imageResourceGroup=aibRhelByosRg1

# location (see possible locations in main docs)
location=westUS2

# your subscription
# get the current subID : 'az account show | grep id'
subscriptionID=<AzureSubscriptionID>

# name of the image to be created
runOutputName=aibCustomRHELByosRo1

# create resource group
az group create -n $imageResourceGroup -l $location

# assign permissions for that resource group
az role assignment create \
    --assignee cf32a0cc-373c-47c9-9156-0db11f6a6dfc \
    --role Contributor \
    --scope /subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup

# Go to the Red Hat Cloud Access Portal, and get the link and checksum, as per this [Quick QuickStart example](https://github.com/danielsollondon/azvmimagebuilder/tree/master/quickquickstarts/6_Creating_a_Custom_Image_using_Red_Hat_Subscription_Licences_to_VHD).	
# paste RHEL image checksum from the cloud access portal here
rhelChecksum="”

# link address must be in double quotes
rhelLinkAddress=" "

# download the example and configure it with your vars
curl https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/quickquickstarts/6_Creating_a_Custom_Image_using_Red_Hat_Subscription_Licences_to_VHD/helloImageTemplateRhelBYOSVhd.json -o helloImageTemplateRhelBYOS1.json

sed -i -e "s/<subscriptionID>/$subscriptionID/g" helloImageTemplateRhelBYOS1.json
sed -i -e "s/<rgName>/$imageResourceGroup/g" helloImageTemplateRhelBYOS1.json
sed -i -e "s/<region>/$location/g" helloImageTemplateRhelBYOS1.json
sed -i -e "s/<rhelChecksum>/$rhelChecksum/g" helloImageTemplateRhelBYOS1.json
sed -i -e "s%<rhelLinkAddress>%$rhelLinkAddress%g" helloImageTemplateRhelBYOS1.json
sed -i -e "s/<rhelLinkAddress>/\&/g" helloImageTemplateRhelBYOS1.json
sed -i -e "s/<runOutputName>/$runOutputName/g" helloImageTemplateRhelBYOS1.json

# submit the image configuration to the VM Image Builder Service
az resource create \
    --resource-group $imageResourceGroup \
    --properties @helloImageTemplateRhelBYOS1.json \
    --is-full-object \
    --resource-type Microsoft.VirtualMachineImages/imageTemplates \
    -n helloImageTemplateRhelBYOStoVhd1

# wait approx 15mins (AIB is downloading the ISO)

# start the image build

az resource invoke-action \
     --resource-group $imageResourceGroup \
     --resource-type  Microsoft.VirtualMachineImages/imageTemplates \
     -n helloImageTemplateRhelBYOStoVhd1 \
     --action Run 

# wait approx 15mins

# get the vhd url
az resource show \
    --ids "/subscriptions/$subscriptionID/resourcegroups/$imageResourceGroup/providers/Microsoft.VirtualMachineImages/imageTemplates/helloImageTemplateRhelBYOStoVhd1/runOutputs/$runOutputName"  \
    --api-version=2019-05-01-preview | grep artifactUri
# The vhd url obtained will look something like https://7a32caf33b93e447f53a6150.blob.core.windows.net/vhds/helloImageTemplateRhelBYOStoVhd1_20190624223943.vhd?se=2019-07-24T22%3A39%3A45Z&sig=TgPcztJ9%2FmDmYq%2F24%2BC%2BF9G5WPJc7D3TMas1xmvPLYo%3D&sp=r&sr=b&sv=2016-05-31
```

## Step 2: Copy VHD to Storage account on Azure Stack

Once the VHD has been created, copy it to an alternative location, as soon as possible. The VHD is stored in a storage account in the temporary Resource Group created when the Image Template is submitted to the Azure Image Builder service. If you delete the Image Template, then you will lose this VHD.
### Connected Scenario
The machine you are attempting a copy with will need to be able to reach out to both Azure and Azure Stack environments. You can copy the VHD from the URL provided in the previous step to Azure Stack using  [az storage blob copy start](https://docs.microsoft.com/en-us/cli/azure/storage/blob/copy?view=azure-cli-latest#az-storage-blob-copy-start) with the --source-uri parameter pointing to this VHD URI.
You may also use [Start-AzureStorageBlobCopy](https://docs.microsoft.com/en-us/powershell/module/azure.storage/start-azurestorageblobcopy?view=azurermps-6.13.0) with the -AbsoluteUri parameter to achieve the same. 

```
# Logging into my Azure Stack. The name of my environment is Orlando					 
az cloud register -n "Orlando" --endpoint-resource-manager "" --suffix-storage-endpoint "" 
az cloud set -n "Orlando"
az login -u user123@contoso.com --tenant myazurestack.onmicrosoft.com
az cloud update --profile 2019-03-01-hybrid

# Create resource group, storage account and container
az group create -l Orlando -n AzSImgBuilder
az storage account create -n strgrhelimg -g AzSImgBuilder -l Orlando --sku Standard_LRS
az storage account list -g AzSImgBuilder --output table
az storage container create -n vhds --account-name strgrhelimg 

# Start the blob copy
az storage blob copy start --destination-blob helloImageTemplateRhelBYOStoVhd1_20190624223943.vhd --destination-container vhds --account-name strgrhelimg --source-uri "https://7a32caf33b93e447f53a6150.blob.core.windows.net/vhds/helloImageTemplateRhelBYOStoVhd1_20190624223943.vhd?se=2019-07-24T22%3A39%3A45Z&sig=TgPcztJ9%2FmDmYq%2F24%2BC%2BF9G5WPJc7D3TMas1xmvPLYo%3D&sp=r&sr=b&sv=2016-05-31"
# confirming the copy is finished
az storage blob show --account-name strgrhelimg --container-name vhds --name helloImageTemplateRhelBYOStoVhd1_20190624223943.vhd
```

### Disconnected Scenario
You can use [Azcopy](https://docs.microsoft.com/en-us/azure/storage/common/storage-use-azcopy) to download the VHD onto your local machine and manually move it to an Azure Stack storage account.


This VHD is now ready to be used to spin up new VMs on Azure Stack. You may follow the below optional steps to make the VHD available as a managed image or as a marketplace item. To make the image available as a marketplace item, you will need to AzCopy to a storage account visible on the Azure Stack Administrator portal.

## Step 4 (Optional): Create a Custom Marketplace Item with this VHD OR Convert VHD to a Managed Image

### Managed Image
Follow the instructions [here](https://docs.microsoft.com/en-us/azure/virtual-machines/windows/capture-image-resource#create-an-image-from-a-vhd-in-a-storage-account) to create a managed image from a generalized VHD in a storage account. You can use this image going forward to create managed VMs.

### Custom Marketplace Item
Follow [this](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-add-vm-image) to offer the VM image on Azure Stack and [this](https://docs.microsoft.com/en-us/azure-stack/operator/azure-stack-create-and-publish-marketplace-item) to publish a custom marketplace item referencing this image. This marketplace item will make the image available to all the Azure Stack tenants.


