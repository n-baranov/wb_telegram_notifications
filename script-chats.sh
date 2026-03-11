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

DATETIME=$(date +'%Y-%m-%d-%H-%M-%S')

CURRENT_FILEPATH=chts
CURRENT_FILENAME=$DATETIME.json
mkdir -p $CURRENT_FILEPATH

curl -s --location --request GET 'https://buyer-chat-api.wildberries.ru/api/v1/seller/chats' --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.result' | jq -r '. |= sort_by(.chatID)' > $CURRENT_FILEPATH/$CURRENT_FILENAME

NEW_CHATS_JSON=$(<$CURRENT_FILEPATH/$CURRENT_FILENAME)
if [ "$NEW_CHATS_JSON" == "[]" ] || [ "$NEW_CHATS_JSON" == null ] || [ "$NEW_CHATS_JSON" == "" ]; then
        echo "Error! Chats is empty"
	rm $CURRENT_FILEPATH/$CURRENT_FILENAME
      	echo "--------------------"
else
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

	# REGULAR RUN WHEN NEW CHANGES FOUND
	if [ $FILES_ARE_DIFFERENT -gt 0 ] && [ $FILE_IS_FIRST -gt 1 ]; then
		  # send messages from bot
                  for k in `seq 1 $CHAT_NUM`; do
                        current_chat_id=chat_id_$k
                        if  [ "${!current_chat_id}" != "" ]; then
                                curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=${!current_chat_id} \
                           		-d text="Новый чат с покупателем!%0A$LK_NAME" &
                                echo "--------------------"
                        fi
                  done
	# FIRST RUN EXCEPTION
	elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -eq 1 ]; then
        	echo "FIRST RUN! Creating base for future comparison"
	elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -gt 1 ]; then
		echo "NO CHANGES FOUND!"
        	rm $CURRENT_FILEPATH/$CURRENT_FILENAME
	fi
		echo "--------------------"
fi
