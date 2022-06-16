fx_version 'cerulean'
use_fxv2_oal 'yes'
game 'gta5'
lua54 'yes'

name 'JLRP-Society'
author 'Mahan Moulaei'
discord 'Mahan#8183'
description 'JolbakLifeRP Society'

version '0.0'

shared_scripts {
	'@JLRP-Framework/shared/locale.lua',
	'config.lua',
	'shared/*.lua',
	'locales/*.lua'
}

server_scripts {
	'@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

client_scripts {
	'client/*.lua'
}

dependencies {
	'oxmysql',
	'JLRP-Framework'
}