#!/bin/bash

STAR="⭐"
CHAT_NUM=4

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

for i in `seq 0 $(( $LENGTH - 1 ))`; do
    SELLER_SKU=$(jq -r '[.[]|select(.)]['$i'].sku[].num' sku.json)
    SELLER_NAME=$(jq -r '[.[]|select(.)]['$i'].name' sku.json)

    echo SELLER_SKU=$SELLER_SKU

    WB_TOKEN_CHANGE=$(curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$SELLER_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.status')
    if  [ $WB_TOKEN_CHANGE == '401' ]; then
      curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=$chat_id_1 -d text="Токен WB изменился! Требуется обновить токен в скрипте на сервере%0A$LK_NAME"
      break
    fi


    CURRENT_FILEPATH=src/$SELLER_NAME/$SELLER_SKU
    CURRENT_FILENAME=$DATETIME.json
    mkdir -p $CURRENT_FILEPATH

    curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=true&take=5000&skip=0&nmId='$SELLER_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.data.feedbacks' | jq -r 'del(.[].answer,.[].state,.[].video,.[].photoLinks,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].bables,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color)' | jq -r '. |= sort_by(.createdDate)' > $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME
    curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$SELLER_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.data.feedbacks' | jq -r 'del(.[].answer,.[].state,.[].video,.[].photoLinks,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].bables,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color)' | jq -r '. |= sort_by(.createdDate)' > $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME

    ANSWERED_JSON=$(<$CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME)
    if [ "$ANSWERED_JSON" == "[]" ] || [ "$ANSWERED_JSON" == null ] || [ "$ANSWERED_JSON" == "" ]; then
        echo "ANSWERED IS EMPTY. LOOKS LIKE AN API RESPONSE ERROR. SKIPPING THIS SKU..."
        echo "--------------------"
        rm $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME
    	continue
    fi

    NOT_ANSWERED_JSON=$(<$CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME)
    if [ "$NOT_ANSWERED_JSON" != "[]" ] && [ "$NOT_ANSWERED_JSON" != null ] && [ "$NOT_ANSWERED_JSON" != "" ]; then
	echo "Unanswered is not empty"
	jq -s '.[0] + .[1]' $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME | jq -r '. |= sort_by(.createdDate)' > $CURRENT_FILEPATH/$CURRENT_FILENAME
	rm $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME
    else
        echo "Unanswered is empty"
	mv $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME $CURRENT_FILEPATH/$CURRENT_FILENAME
	rm $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME
    fi


# CHECK FOR EMPTY JSON
    CURRENT_JSON=$(<$CURRENT_FILEPATH/$CURRENT_FILENAME)
    if  [ "$CURRENT_JSON" == "[]" ] || [ "$CURRENT_JSON" == "" ] || [ "$CURRENT_JSON" == null ]; then
      echo "JSON IS EMPTY. SKIPPING THIS SKU..."
      rm $CURRENT_FILEPATH/$CURRENT_FILENAME
      echo "--------------------"
      continue
    fi

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
        mkdir -p reports
        CAUGHT_DIFFERENCE=$(jq --slurpfile s $CURRENT_FILEPATH/$PREVIOUS_FILENAME '[ .[] | . as $o | if (reduce $s[0][] as $i
     ([]; . + [($o | contains($i))]) | any) then empty else $o end ]' $CURRENT_FILEPATH/$CURRENT_FILENAME )
	echo CAUGHT_DIFFERENCE=$CAUGHT_DIFFERENCE
        if  [ "$CAUGHT_DIFFERENCE" == "[]" ] || [ "$CAUGHT_DIFFERENCE" == "" ] || [ "$CAUGHT_DIFFERENCE" == null ]; then
        	echo "ERROR: CAUGHT DIFFERENCE IS EMPTY. SKIPPING THIS SKU..."
        	continue
        fi

	echo $CAUGHT_DIFFERENCE >> reports/$DATETIME-$SELLER_NAME-$SELLER_SKU
	CHANGES_COUNT=$(jq length reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
	echo CHANGES_COUNT=$CHANGES_COUNT
       	for j in `seq 0 $(( $CHANGES_COUNT - 1 ))`
       	do
   		  echo j=$j
          	  JSON_SUPPLIER_ARTICLE=$(jq -r '.['$j'].productDetails.supplierArticle' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
           	  JSON_USERNAME=$(jq -r '.['$j'].userName' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
           	  JSON_TEXT=$(jq -r '.['$j'].text' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
                  JSON_PROS=$(jq -r '.['$j'].pros' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
                  JSON_CONS=$(jq -r '.['$j'].cons' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
           	  JSON_PRODUCT_VALUE=$(jq -r '.['$j'].productValuation' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
           	  JSON_DATE_GMT=$(jq -r '.['$j'].createdDate' reports/$DATETIME-$SELLER_NAME-$SELLER_SKU)
		  JSON_DATE=$(TZ=Europe/Moscow date -d "$JSON_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
           	  JSON_STARS=
           	  for k in `seq 1 $JSON_PRODUCT_VALUE`
           	  do
              	  	JSON_STARS="$JSON_STARS$STAR"
           	  done
		  # send messages from bot
		  for k in `seq 1 $CHAT_NUM`; do
			current_chat_id=chat_id_$k
			if  [ "${!current_chat_id}" != "" ]; then
	                	curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=${!current_chat_id} \
                        		-d text="Новая оценка: $JSON_STARS %0A$LK_NAME %0AАртикул: $JSON_SUPPLIER_ARTICLE %0AДата: $JSON_DATE %0AПользователь: $JSON_USERNAME %0AПлюсы: $JSON_PROS %0AМинусы: $JSON_CONS %0AТекст: $JSON_TEXT" &
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
done
