
#!/bin/bash

set -e

FILE_FINAL=/etc/systemd/system/vault.d/config.json
FILE_TMP=$FILE_FINAL.tmp

sudo sed -i -- "s/{{ YOUR_ATLAS_TOKEN }}/${atlas_token}/g" $FILE_TMP
sudo sed -i -- "s/{{ YOUR_ATLAS_USERNAME }}/${atlas_username}/g" $FILE_TMP

# Note: placeholders below replaced by bash, not the Terraform go template.
METADATA_INSTANCE_ID=`curl http://169.254.169.254/2014-02-25/meta-data/instance-id`
sudo sed -i -- "s/{{ instance-id }}/$METADATA_INSTANCE_ID/g" $FILE_TMP

sudo mv $FILE_TMP $FILE_FINAL

exit 0
