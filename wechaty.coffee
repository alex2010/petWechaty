{Wechaty} = require 'wechaty'
{PuppetPadplus} = require 'wechaty-puppet-padplus'
qt = require 'qrcode-terminal'

cfg = require './cfg'
petRob = require './wr/pet'
selfRob = require './wr/self'

module.exports = (pre, app, c, qiniu)->
	puppet = new PuppetPadplus
		token: if app.env then cfg.token.test else cfg.token.prod

	cf.petBot = bot = new Wechaty {puppet, name: cfg.wtName}

	bot.on 'scan', (qrcode)->
		try
			qt.generate qrcode,
				small: true
			await gt(c.code, 'wtSender').sendText cfg.woid.owner, "#{cfg.actUrl}/qrImg?link=#{qrcode}"
			log 'wechaty running...'
		catch e
			log e

	bot.on 'login', (user) ->
		log("#{user} login")
		if user.name() is cfg.wtAccount.customerService
			petRob pre, app, bot, c, qiniu
		selfRob pre, app, bot, c, qiniu

	bot.on 'logout', (user) ->
		log("#{user} logout")
		fs.unlink "#{_path}/#{cfg.wtName}.memory-card.json", ->

	bot.on 'error', (e)->
		log e

	await bot.start()
