fx_version 'cerulean'
game 'gta5'

author 'Senior FiveM Developer'
description 'Wind Turbine Operator - Semi-AFK Job'
version '1.0.0'

-- Optional dependency: lb-phone for phone notifications
-- If lb-phone is not installed, the script will still work (notifications will be skipped)
dependency 'lb-phone'

shared_scripts {
    'config.lua'
}

client_scripts {
    'config.lua',  -- Load lại config để đảm bảo
    'client/main.lua'
}

server_scripts {
    'config.lua',  -- Load lại config để đảm bảo
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

ui_page 'nui-dist/index.html'

files {
    'nui-dist/index.html',
    'nui-dist/assets/*.js',
    'nui-dist/assets/*.css',
    'nui-dist/img/*.png',
    'nui-dist/img/*.svg'
}
