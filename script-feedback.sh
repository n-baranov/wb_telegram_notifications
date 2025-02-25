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

LENGTH=$(jq length sku-new.json)
DATETIME=$(date +'%Y-%m-%d-%H-%M-%S')

for i in `seq 0 $(( $LENGTH - 1 ))`; do
    CURRENT_GROUP=$(jq -r '.['$i'].group' sku-new.json)
    echo "===================="
    echo "CURRENT_GROUP=$CURRENT_GROUP"
    echo "===================="
    CURRENT_GROUP_LENGTH=$(jq -r '[.[]|select(.group=="'$CURRENT_GROUP'")][].sku[].num' sku-new.json | wc -l)
    for n in `seq 0 $(( $CURRENT_GROUP_LENGTH - 1 ))`; do
        CURRENT_SKU=$(jq -r '[.[]|select(.group=="'$CURRENT_GROUP'")][].sku['$n'].num' sku-new.json)
        echo "n=$n; CURRENT_SKU=$CURRENT_SKU"

        WB_TOKEN_CHANGE=$(curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$CURRENT_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' | jq -r '.status')
        if  [ $WB_TOKEN_CHANGE == '401' ]; then
            curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=$chat_id_1 -d text="Токен WB изменился! Требуется обновить токен в скрипте на сервере%0A$LK_NAME"
        break
        fi

        CURRENT_FILEPATH=src/$CURRENT_SKU
        CURRENT_FILENAME=$DATETIME.json
        mkdir -p $CURRENT_FILEPATH

        curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=true&take=5000&skip=0&nmId='$CURRENT_SKU  --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' > $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME
        echo $(jq -r '.data.feedbacks' $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME     | jq -r 'del(.[].answer,.[].state,.[].video,.[].photoLinks,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color,.[].subjectName,.[].parentFeedbackId,.[].childFeedbackId)' | jq -r '. |= sort_by(.createdDate)') > $CURRENT_FILEPATH/ANSWERED_$CURRENT_FILENAME
        curl -s --location --request GET 'https://feedbacks-api.wb.ru/api/v1/feedbacks?isAnswered=false&take=5000&skip=0&nmId='$CURRENT_SKU --header 'Authorization: '$WB_TOKEN --header 'Content-Type: application/json' > $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME
        echo $(jq -r '.data.feedbacks' $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME | jq -r 'del(.[].answer,.[].state,.[].video,.[].photoLinks,.[].matchingSize,.[].isAbleSupplierFeedbackValuation,.[].supplierFeedbackValuation,.[].isAbleSupplierProductValuation,.[].supplierProductValuation,.[].isAbleReturnProductOrders,.[].returnProductOrdersDate,.[].subjectId,.[].subjectName,.[].wasViewed,.[].productDetails.size,.[].productDetails.imtId,.[].productDetails.productName,.[].productDetails.supplierName,.[].productDetails.brandName,.[].color,.[].subjectName,.[].parentFeedbackId,.[].childFeedbackId)' | jq -r '. |= sort_by(.createdDate)') > $CURRENT_FILEPATH/NOT_ANSWERED_$CURRENT_FILENAME

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
                    JSON_USERNAME=$(jq -r '.['$j'].userName' reports/$DATETIME-$CURRENT_SKU)
                    JSON_TEXT=$(jq -r '.['$j'].text' reports/$DATETIME-$CURRENT_SKU)
                    JSON_PROS=$(jq -r '.['$j'].pros' reports/$DATETIME-$CURRENT_SKU)
                    JSON_CONS=$(jq -r '.['$j'].cons' reports/$DATETIME-$CURRENT_SKU)
                    JSON_BABLES=$(jq -r '.['$j'].bables' reports/$DATETIME-$CURRENT_SKU | tr '\n' ' ')
                    JSON_ORDER_DATE_GMT=$(jq -r '.['$j'].lastOrderCreatedAt' reports/$DATETIME-$CURRENT_SKU)
                    JSON_ORDER_DATE=$(TZ=Europe/Moscow date -d "$JSON_ORDER_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
                    JSON_PRODUCT_VALUE=$(jq -r '.['$j'].productValuation' reports/$DATETIME-$CURRENT_SKU)
                    JSON_DATE_GMT=$(jq -r '.['$j'].createdDate' reports/$DATETIME-$CURRENT_SKU)
                    JSON_DATE=$(TZ=Europe/Moscow date -d "$JSON_DATE_GMT" +'%Y-%m-%d %H:%M:%S')
                    JSON_STARS=
                    for k in `seq 1 $JSON_PRODUCT_VALUE`
                    do
                            JSON_STARS="$JSON_STARS$STAR"
                    done

                    # check if feedback is more than one month old
                    JSON_DATE_TIMESTAMP=$(date -ud "$JSON_ORDER_DATE_GMT" +"%s")
                    ONE_MONTH_AGO_TIMESTAMP=$(date -ud "1 month ago" +"%s")
                    if [ $JSON_DATE_TIMESTAMP -gt $ONE_MONTH_AGO_TIMESTAMP ]; then
                            # send messages from bot
                            for k in `seq 1 $CHAT_NUM`; do
                                    current_chat_id=chat_id_$k
                                    if  [ "${!current_chat_id}" != "" ]; then
                                            curl -s -X POST 'https://api.telegram.org/bot'$TG_BOT_TOKEN'/sendMessage' -d chat_id=${!current_chat_id} \
                                                    -d text="Новая оценка: $JSON_STARS %0A$LK_NAME %0AАртикул: $JSON_SUPPLIER_ARTICLE %0AДата: $JSON_DATE %0AПользователь: $JSON_USERNAME %0AПлюсы: $JSON_PROS %0AМинусы: $JSON_CONS %0AТекст: $JSON_TEXT%0AНедостатки: $JSON_BABLES%0AТовар был заказан: $JSON_ORDER_DATE" &
                                            echo "--------------------"
                                    fi
                            done
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
