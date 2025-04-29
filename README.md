This scripts need jq, jd (https://github.com/josephburnett/jd) and bash to be installed on your Linux system.
config and sku-new.json file should be located in the same directory (/path/to/your/workspace/)

Before you start first you need to create your Telegram bot using BotFather and start a dialog with it (every account to receive Telegram notifications should start a dialog with your bot first)

Run your scripts using cron like this:
*/2 * * * *   /path/to/your/script/repo/script-feedback.sh /path/to/your/workspace/config
