#!/bin/bash
# A helper script to get an S3 object, part by part, e.g., for those cases
# where it might no longer be possible to do so 'in one go'... 
# 
# If REPLACE_MISSING_PARTS_WITH_ZEROS is set to true (the default case),
# then any parts that /cannot/ be downloaded will be replaced with a matching
# number of zeros --- this should make it easier to 'fsck' or otherwise
# 'repair' objects whose underlying file types have a corresponding 'check',
# 'fix' or repair utility.
#
# Author: Peter Metz
ENDPOINT_URL=https://s3-eu-central-1.ionoscloud.com
BUCKET=replace-with-the-actual-bucket-name
OBJECT=replace-with-the-actual-object-name

REPLACE_MISSING_PARTS_WITH_ZEROS=true
KEEP_PARTS=false


# Obtain the first part and create a zero'ed out 'blank' file of the same size
echo "About to retrieve ${ENDPOINT_URL}/${BUCKET}/${KEY} part-wise..."
if [[ "$REPLACE_MISSING_PARTS_WITH_ZEROS" != true ]]; then
  echo "... NOTE that missing parts will /not/ be replaced by zeroed-out blocks;"
  echo "...   this will result in a smaller output file"
fi
PARTS_COUNT=`aws s3api get-object --endpoint-url ${ENDPOINT_URL} --bucket ${BUCKET} --key ${OBJECT} ${OBJECT}.part.1 --part-number 1 | jq .PartsCount`
PART_SIZE=`wc -c ${OBJECT}.part.1 | cut -d' ' -f1`

echo "... ${OBJECT} consists of ${PARTS_COUNT} parts, each ${PART_SIZE} bytes in size"
dd if=/dev/zero of=${OBJECT}.zeros bs=1 count=${PART_SIZE}


# Retrieve the remaining parts and start 'reconstructing' the object, optionally
# removing the part-files as we go...
cp ${OBJECT}.part.1 ${OBJECT}.recovered
for (( i=2; i<=${PARTS_COUNT}; i++ )); do
  aws s3api get-object --endpoint-url ${ENDPOINT_URL} --bucket ${BUCKET} --key ${OBJECT} ${OBJECT}.part.$i --part-number $i > /dev/null
  retval="$?"
  if [ $retval -eq 0 ]; then
    echo "... successfully retrieved Part $i"
    cat ${OBJECT}.part.$i >> ${OBJECT}.recovered
  else
    if [[ "$REPLACE_MISSING_PARTS_WITH_ZEROS" = true ]]; then
      echo "... ERROR retrieving Part $i; replaced with a zeroed-out file"
      cat ${OBJECT}.zeros >> ${OBJECT}.recovered
    else
      echo "... ERROR retrieving Part $i; skipping"
    fi
  fi
  if [[ "$KEEP_PARTS" != true ]]; then
    rm -f ${OBJECT}.part.$i
  fi
done


# And clean up after ourselves...
if [[ "$KEEP_PARTS" != true ]]; then
  rm -f ${OBJECT}.part.1 ${OBJECT}.zeros
fi

