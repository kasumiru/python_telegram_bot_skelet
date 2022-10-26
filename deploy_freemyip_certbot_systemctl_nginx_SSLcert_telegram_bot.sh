

# скрипт подготовки nginx domain.conf 
# domain create prepare domain 
# nginx подготовка файла 
# установка DNS записи для бесплатного домена freemyip.com


# получение бесплатного домена:
###
перейти на https://freemyip.com
check domain:
mydomain.freemyip.com
далее устанавливается DNS запись так: curl путь_который_будет в поле на сайте, к примеру вот так выполнить в баше:
curl https://freemyip.com/update?token=5c0egdg2eggasfasgwehsd6&domain=mydomain.freemyip.com
после чего можно уже проверять, что запись установилась:
ping mydomain.freemyip.com


# install certbot install 
# python3 -m pip install certbot certbot-nginx certbot-dns-cloudflare
python3 -m pip install certbot certbot-nginx

domain="mydomain.freemyip.com"
app_port="8108"
telegram_token="500000000:AAxxxxxxxxxxxxxxxxxxxxxxx"
nginx_ssl_port="443"

stemctl_bot_name="my_telegram_bot.service"
python_bot_filename="python_telegram_bot.py"
python_bot_working_dir="/srv/tg/bot"
mkdir -p ${python_bot_working_dir}

# NOT FOR PROD:
certbot certonly --agree-tos --non-interactive --pre-hook "systemctl stop nginx" --post-hook "systemctl start nginx" --standalone --preferred-challenges http -d ${domain}
# FOR PROD: CERTIFICATE letsencrypt certbot generate cerficicate
# certbot certonly --dns-cloudflare --dns-cloudflare-credentials /root/.certbot/cloudflare/cloudflare.ini -d ${domain} --agree-tos --non-interactive 




# install latext nginx
sudo apt install curl gnupg2 ca-certificates lsb-release debian-archive-keyring
curl https://nginx.org/keys/nginx_signing.key | gpg --dearmor \
    | sudo tee /usr/share/keyrings/nginx-archive-keyring.gpg >/dev/null
gpg --dry-run --quiet --import --import-options import-show /usr/share/keyrings/nginx-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] \
http://nginx.org/packages/debian `lsb_release -cs` nginx" \
    | sudo tee /etc/apt/sources.list.d/nginx.list
apt update
apt install nginx

# nginx.conf:
cp /etc/nginx/nginx.conf{,-}
echo "###" > /etc/nginx/nginx.conf
cat /etc/nginx/nginx.conf- >> /etc/nginx/nginx.conf
sed -z "s/http {/http {\n    server_tokens off;\n/g" -i /etc/nginx/nginx.conf
# default.conf
cp /etc/nginx/conf.d/default.conf{,-}
printf "server {\n    listen       80;\n    server_name  localhost;\n    return 403;\n}" > /etc/nginx/conf.d/default.conf

systemctl restart nginx
systemctl status nginx
nginx -t && nginx -s reload
nginx -v






# nginx prepare 
rm template_domain.nginx.conf*
wget https://raw.githubusercontent.com/kasumiru/templates/main/template_domain.nginx.conf
domain_file="${domain}.conf"
default_file="template_domain.nginx.conf"
curdate=$(date '+%Y.%m.%d_%H_%M_%s')
echo -e "${Green} backup old domain conf file"
cp /etc/nginx/conf.d/${domain_file} /etc/nginx/conf.d/${domain_file}_${curdate}_bkp
cp "${default_file}" "${domain_file}"
sed -s "s/TEMPLATEDOMAIN/${domain}/g"         -i "${domain_file}"
sed -s "s/APPTCPPORT/${app_port}/g" -i "${domain_file}"
mv ${domain_file} /etc/nginx/conf.d/${domain_file}
nginx -t && nginx -s reload
rm template_domain.nginx.conf*




# WEBHOOK: регистрация телеграм webhook web hook вебхук вубхука телеграм
curl https://api.telegram.org/bot${telegram_token}/setWebhook?url=https://${domain}




# сам бот python простой автоответ
yes | python3 -m pip uninstall telebot
python3 -nm pip install pyTelegramBotAPI

# скачиваем с гитхаба скелет бота
curl https://raw.githubusercontent.com/kasumiru/python_telegram_bot_skelet/main/simple_telegram_bot_webhook.py -L > ${full_python_bot_filename}
# заменяем дефолтные переменные и токен на павильные
sed "s/telegram_bot_token_PLACEHOLDER/${telegram_token}/g" -i ${full_python_bot_filename}; head ${full_python_bot_filename}
sed "s/tcp_port = 8811/tcp_port = ${app_port}/g" -i ${full_python_bot_filename}; head ${full_python_bot_filename}




# prepare systemctl service file for python script
full_python_bot_filename="${python_bot_working_dir}/${python_bot_filename}"
full_stemctl_bot_name="/lib/systemd/system/${stemctl_bot_name}"

rm ${full_stemctl_bot_name}
rm /etc/systemd/system/${stemctl_bot_name} 
systemctl daemon-reload

echo "[Unit]" > ${full_stemctl_bot_name}
echo "Description=python telegram downloader bot" >> ${full_stemctl_bot_name}
echo "After=network.target auditd.service" >> ${full_stemctl_bot_name}
echo "" >> ${full_stemctl_bot_name}
echo "[Service]" >> ${full_stemctl_bot_name}
echo "WorkingDirectory=${python_bot_working_dir}/" >> ${full_stemctl_bot_name}
echo "ExecStart=/usr/bin/env python3 ${full_python_bot_filename}" >> ${full_stemctl_bot_name}
echo "KillMode=process" >> ${full_stemctl_bot_name}
echo "Restart=always" >> ${full_stemctl_bot_name}
echo "" >> ${full_stemctl_bot_name}
echo "[Install]" >> ${full_stemctl_bot_name}
echo "WantedBy=multi-user.target" >> ${full_stemctl_bot_name}

systemctl daemon-reload
systemctl enable ${stemctl_bot_name}
systemctl stop ${stemctl_bot_name}
systemctl restart ${stemctl_bot_name}
systemctl status ${stemctl_bot_name}



# для ручной отладки (для разработки) останавливаем systemctl файл:
systemctl stop ${stemctl_bot_name}
#запускаем и через vim запускаем хоткеем (очень советую, хоткей ctl+d, в соседнем репозитории нужно скачать и заменить .vimrc)
vim ${full_python_bot_filename}
