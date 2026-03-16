#!/bin/bash

STAR="⭐"
CHAT_NUM=5

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
TG_PROXY="${ary[TG_PROXY]}"

cd $LK_PATH

LENGTH=$(jq length sku.json)
DATETIME=$(date +'%Y-%m-%d-%H-%M-%S')
 
if [ ! -f jobs/send_messages.sh ]; then
    mkdir -p jobs
    echo "#!/bin/bash" > jobs/send_messages.sh
    echo "set -e" >> jobs/send_messages.sh
fi

# CHECK WB TOKEN VALIDITY
FIRST_GROUP=$(jq -r '.[0].group' sku.json)
FIRST_SKU=$(jq -r '[.[]|select(.group=="'$FIRST_GROUP'")][].sku[0].num' sku.json)
REQUEST_STATUS=$(curl -s --location --request GET 'https://feedbacks-api.wildberries.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$FIRST_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.status')
if  [ $REQUEST_STATUS == '401' ]; then
    curl -s $TG_PROXY -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=$chat_id_1 -d text="Токен WB изменился! Требуется обновить токен в скрипте на сервере%0A$LK_NAME"
    break
fi

for i in `seq 0 $(( $LENGTH - 1 ))`; do
    CURRENT_GROUP=$(jq -r '.['$i'].group' sku.json)
    echo "===================="
    echo "CURRENT_GROUP=$CURRENT_GROUP"
    echo "===================="
    CURRENT_GROUP_LENGTH=$(jq -r '[.[]|select(.group=="'$CURRENT_GROUP'")][].sku[].num' sku.json | wc -l)
    for n in `seq 0 $(( $CURRENT_GROUP_LENGTH - 1 ))`; do
        CURRENT_SKU=$(jq -r '[.[]|select(.group=="'$CURRENT_GROUP'")][].sku['$n'].num' sku.json)
        date +'%Y-%m-%d-%H-%M-%S'
        echo "n=$n; CURRENT_SKU=$CURRENT_SKU"
        CURRENT_FILEPATH=src/$CURRENT_SKU
        CURRENT_FILENAME=$DATETIME.json
        mkdir -p $CURRENT_FILEPATH

        curl -s --location --request GET 'https://feedbacks-api.wildberries.ru/api/v1/feedbacks?isAnswered=true&take=5000&skip=0&nmId='$CURRENT_SKU  --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' > $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME
        echo $(jq -r '.data.feedbacks' $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME     | jq -r 'del(.[].answer,.[].state,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color,.[].subjectName,.[].childFeedbackId)' | jq -r '. |= sort_by(.createdDate)') > $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME
        curl -s --location --request GET 'https://feedbacks-api.wildberries.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$CURRENT_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' > $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME
        echo $(jq -r '.data.feedbacks' $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME | jq -r 'del(.[].answer,.[].state,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color,.[].subjectName,.[].childFeedbackId)' | jq -r '. |= sort_by(.createdDate)') > $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME

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
            PREVIOUS_FILENAME=0-feedback-pool.json
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
                    rm $CURRENT_FILEPATH/$CURRENT_FILENAME
                    echo "--------------------"
                    continue
            fi

            echo $CAUGHT_DIFFERENCE >> reports/$DATETIME-$CURRENT_SKU
            CHANGES_COUNT=$(jq length reports/$DATETIME-$CURRENT_SKU)
            echo CHANGES_COUNT=$CHANGES_COUNT
            for j in `seq 0 $(( $CHANGES_COUNT - 1 ))`
            do
                    echo j=$j
                    JSON_SUPPLIER_ARTICLE=$(jq -r '.['$j'].productDetails.supplierArticle' reports/$DATETIME-$CURRENT_SKU)
                    JSON_SUPPLIER_ARTICLE=$(sed 's|\&||g' <<<$JSON_SUPPLIER_ARTICLE)
                    JSON_USERNAME=$(jq -r '.['$j'].userName' reports/$DATETIME-$CURRENT_SKU)
                    JSON_TEXT=$(jq -r '.['$j'].text' reports/$DATETIME-$CURRENT_SKU | tr '*' '#' || true)
                    JSON_PROS=$(jq -r '.['$j'].pros' reports/$DATETIME-$CURRENT_SKU)
                    JSON_CONS=$(jq -r '.['$j'].cons' reports/$DATETIME-$CURRENT_SKU)
                    JSON_BABLES=$(jq -r '.['$j'].bables' reports/$DATETIME-$CURRENT_SKU | tr '\n' ' ' | tr  -d '"' || true)
                    JSON_ORDER_DATE_GMT=$(jq -r '.['$j'].lastOrderCreatedAt' reports/$DATETIME-$CURRENT_SKU)
                    JSON_ORDER_DATE=$(TZ=Europe/Moscow date -d "$JSON_ORDER_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
                    JSON_PRODUCT_VALUE=$(jq -r '.['$j'].productValuation' reports/$DATETIME-$CURRENT_SKU)
                    JSON_PARENT_FEEDBACK_ID=$(jq -r '.['$j'].parentFeedbackId' reports/$DATETIME-$CURRENT_SKU)
                    JSON_ORDER_STATUS=$(jq -r '.['$j'].orderStatus' reports/$DATETIME-$CURRENT_SKU)
                    JSON_DATE_GMT=$(jq -r '.['$j'].createdDate' reports/$DATETIME-$CURRENT_SKU)
                    JSON_DATE=$(TZ=Europe/Moscow date -d "$JSON_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
                    JSON_STARS=
                    for k in `seq 1 $JSON_PRODUCT_VALUE`
                    do
                            JSON_STARS="$JSON_STARS$STAR"
                    done

                    CURL_MESSAGE_PREFIX="Новый отзыв"
                    if [ "$JSON_PARENT_FEEDBACK_ID" != null ]; then
                        CURL_MESSAGE_PREFIX="Дополненный отзыв"
                    fi
                    CURL_ORDER_STATUS="Выкуп"
                    if [ "$JSON_ORDER_STATUS" == "returned" ]; then
                        CURL_ORDER_STATUS="Возврат"
                    elif [ "$JSON_ORDER_STATUS" == "rejected" ]; then
                        CURL_ORDER_STATUS="Отказ на ПВЗ"
                    fi
                    CURL_MESSAGE_BODY="$CURL_MESSAGE_PREFIX: $JSON_STARS %0A$LK_NAME %0AАртикул: $JSON_SUPPLIER_ARTICLE %0AДата: $JSON_DATE %0AПользователь: $JSON_USERNAME %0AПлюсы: $JSON_PROS %0AМинусы: $JSON_CONS %0AТекст: $JSON_TEXT %0AПримечание: $JSON_BABLES %0AСтатус заказа: $CURL_ORDER_STATUS %0AТовар был заказан: $JSON_ORDER_DATE"

                    CURL_METHOD="sendMessage"
                    CURL_DATA="text='$CURL_MESSAGE_BODY'"
                    JSON_MEDIA_COUNT=$(jq -r '.['$j'].photoLinks | length' reports/$DATETIME-$CURRENT_SKU)
                    if [ $JSON_MEDIA_COUNT -gt 0 ]; then
                        JSON_IMG_URL=$(jq -r '.['$j'].photoLinks[0].fullSize' reports/$DATETIME-$CURRENT_SKU)
                        JSON_MEDIA="[{\"type\": \"photo\",\"media\": \"$JSON_IMG_URL\",\"caption\": \"$CURL_MESSAGE_BODY\"}"
                        for l in `seq 1 $(( $JSON_MEDIA_COUNT - 1 ))`
                        do
                            JSON_IMG_URL=$(jq -r '.['$j'].photoLinks['$l'].fullSize' reports/$DATETIME-$CURRENT_SKU)
                            JSON_MEDIA=$JSON_MEDIA",{\"type\": \"photo\",\"media\": \"$JSON_IMG_URL\"}"
                        done
                        JSON_MEDIA=$JSON_MEDIA"]"
                        CURL_METHOD="sendMediaGroup"
                        CURL_DATA="media='$JSON_MEDIA'"
                    fi

                    # check if feedback is more than one month old
                    JSON_DATE_TIMESTAMP=$(date -ud "$JSON_DATE_GMT" +"%s")
                    ONE_MONTH_AGO_TIMESTAMP=$(date -ud "1 month ago" +"%s")
                    if [ $JSON_DATE_TIMESTAMP -gt $ONE_MONTH_AGO_TIMESTAMP ]; then
                            # collect curl commands in jobs/send_messages.sh
                            for k in `seq 1 $CHAT_NUM`; do
                                    current_chat_id=chat_id_$k
                                    if  [ "${!current_chat_id}" != "" ]; then
                                            echo "sleep 1 && curl -s $TG_PROXY -X POST 'https://api.telegram.org/bot$TG_BOT_TOKEN/$CURL_METHOD' -d chat_id=${!current_chat_id} -d $CURL_DATA" >> jobs/send_messages.sh
                                            echo "--------------------"
                                    fi
                            done
                    else
                        echo "FEEDBACK IS OLDER THAN 1 MONTH"
                        echo "--------------------"
                    fi
            done
            jq -s '.[0] + .[1]' $CURRENT_FILEPATH/$PREVIOUS_FILENAME reports/$DATETIME-$CURRENT_SKU | jq -r '. |= sort_by(.createdDate)' > $CURRENT_FILEPATH/tmp.json
            mv $CURRENT_FILEPATH/tmp.json $CURRENT_FILEPATH/$PREVIOUS_FILENAME
            rm $CURRENT_FILEPATH/$CURRENT_FILENAME
    # FIRST RUN EXCEPTION
        elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -eq 1 ]; then
                echo "FIRST RUN! Creating feedback pool for future comparison"
                mv $CURRENT_FILEPATH/$CURRENT_FILENAME $CURRENT_FILEPATH/0-feedback-pool.json
        elif [ $FILES_ARE_DIFFERENT -eq 0 ] && [ $FILE_IS_FIRST -gt 1 ]; then
            echo "NO CHANGES FOUND!"
            rm $CURRENT_FILEPATH/$CURRENT_FILENAME
        fi
        echo "--------------------"
    done
done

# SEND MESSAGES FROM BOT
timeout 60 bash jobs/send_messages.sh
CURL_OUTPUT=$(echo $?)
if [ $CURL_OUTPUT -eq 0 ]; then
    rm jobs/send_messages.sh
fi
