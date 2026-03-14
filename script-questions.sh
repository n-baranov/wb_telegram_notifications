#!/bin/bash

CHAT_NUM=10

declare -A ary
pat='^([^[:space:]]+)[[:space:]]*=[[:space:]]*"([^"]+)"$'
while IFS= read -r line; do
    if [[ $line =~ $pat ]]; then
        ary[${BASH_REMATCH[1]}]="${BASH_REMATCH[2]}"
    fi
done < $1

for i in `seq 1 $CHAT_NUM`; do
        declare chat_id_$i="${ary[chat_id_$i]}"
done
TG_BOT_TOKEN="${ary[TG_BOT_TOKEN]}"
WB_TOKEN="${ary[WB_TOKEN]}"
LK_NAME="${ary[LK_NAME]}"
LK_PATH="${ary[LK_PATH]}"

cd $LK_PATH

LENGTH=$(jq length sku.json)
DATETIME=$(date +'%Y-%m-%d-%H-%M-%S')

CURRENT_FILEPATH=qsts
CURRENT_FILENAME=$DATETIME.json
mkdir -p $CURRENT_FILEPATH

curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/questions?isAnswered=false&take=5000&skip=0' --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' > $CURRENT_FILEPATH/$CURRENT_FILENAME
echo $(jq -r '.data.questions' $CURRENT_FILEPATH/$CURRENT_FILENAME | jq -r 'del(.[].answer,.[].state,.[].wasViewed,.[].isWarned,.[].productDetails.size,.[].productDetails.nmId,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName)' | jq -r '. |= sort_by(.createdDate)') > $CURRENT_FILEPATH/$CURRENT_FILENAME

    NOT_ANSWERED_JSON=$(<$CURRENT_FILEPATH/$CURRENT_FILENAME)
    if [ "$NOT_ANSWERED_JSON" != "[]" ] && [ "$NOT_ANSWERED_JSON" != null ] && [ "$NOT_ANSWERED_JSON" != "" ]; then
        echo "New questions detected!"

        FILE_IS_FIRST=$(ls -1 $CURRENT_FILEPATH | wc -l)
        if [ $FILE_IS_FIRST -eq 1 ]; then
            echo "This is the first run"
            FILES_ARE_DIFFERENT=0
        else
            echo "This is not the first run"
            PREVIOUS_FILENAME=$(ls -1 $CURRENT_FILEPATH | sort | tail -n 2 | head -n 1)
            echo PREVIOUS_FILENAME=$PREVIOUS_FILENAME
            FILES_ARE_DIFFERENT=$(jd -set $CURRENT_FILEPATH/$PREVIOUS_FILENAME $CURRENT_FILEPATH/$CURRENT_FILENAME | wc -l)
            echo FILES_ARE_DIFFERENT=$FILES_ARE_DIFFERENT
        fi


        if [ $FILES_ARE_DIFFERENT -gt 0 ] && [ $FILE_IS_FIRST -gt 1 ]; then
	    CHANGES_COUNT=$(jq length $CURRENT_FILEPATH/$CURRENT_FILENAME)
            echo CHANGES_COUNT=$CHANGES_COUNT
            for j in `seq 0 $(( $CHANGES_COUNT - 1 ))`
            do
                  echo j=$j
                  JSON_TEXT=$(jq -r '.['$j'].text' $CURRENT_FILEPATH/$CURRENT_FILENAME)
                  JSON_DATE_GMT=$(jq -r '.['$j'].createdDate' $CURRENT_FILEPATH/$CURRENT_FILENAME)
                  JSON_DATE=$(TZ=Europe/Moscow date -d "$JSON_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
                  JSON_SKU=$(jq -r '.['$j'].productDetails.supplierArticle' $CURRENT_FILEPATH/$CURRENT_FILENAME)
                  # send messages from bot
                  for k in `seq 1 $CHAT_NUM`; do
                        current_chat_id=chat_id_$k
                        if  [ "${!current_chat_id}" != "" ]; then
	                	curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=${!current_chat_id} \
             	                        -d text="Новый вопрос! %0A$LK_NAME %0AАртикул: $JSON_SKU %0AДата: $JSON_DATE %0AТекст: $JSON_TEXT" &
                                echo "--------------------"
                        fi
                  done
            done
# FIRST RUN EXCEPTION
        elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -eq 1 ]; then
             echo "FIRST RUN! Creating base for future comparison"
        elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -gt 1 ]; then
            echo "NO CHANGES FOUND!"
            rm $CURRENT_FILEPATH/$CURRENT_FILENAME
        fi
        echo "--------------------"

    else
        echo "No new questions"
        echo "--------------------"
	rm $CURRENT_FILEPATH/$CURRENT_FILENAME
    fi

