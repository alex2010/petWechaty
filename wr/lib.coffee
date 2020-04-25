{FileBox, UrlLink, MiniProgram} = require('wechaty')
qr = require('qr-image')
cfg = require '../cfg'

module.exports = (c, bot, qiniu) ->
	dly = util.dly

	pickContact = (name)->
		if name
			try
				await bot.Contact.find {name}
			catch e
				log e
				null
		else
			null

	pickContactId = (id)->
		if id
			try
				await bot.Contact.load id
			catch e
				log e
				null
		else
			null

	pickRoom = (topic)->
		if _.isString topic
			await bot.Room.find {topic}
		else if topic
			topic
		else
			null

	fRoom = (fn)->
		nn = "#{fn}#"
		rm = await pickRoom nn
		if rm
			return rm
		else
			return await pickRoom fn

	fcRoom = (fn, act)->
		nn = "#{fn}#"
		if rm = await pickRoom fn
			au = await rm.memberAll()
			if au.length < 90
				return rm
			else
				if rm = await pickRoom nn
					return rm
		pu = []
		for it in cfg.wtAccount.initUser
			pu.push (await pickContact(it))
		ngn = if rm
			nn
		else
			fn
		rm = await bot.Room.create(pu, ngn)
		for it in (act.master || []).concatBy act.speaker
			u = await pickContact(it.username)
			pu.push u if u
		sendPicTxt rm, 'Room init', tu.refFile(act, 'ad')
		return rm

	addFriend = (u, msg)->
		try
			await dly(8)
			await bot.Friendship.add u, (msg || null)
		catch e
			log e
			await alex.say 'AF fail: ' + u.name()

	saveQrCode = (rm, scope, fn)->
		if _.isString rm
			rm = await pickRoom rm
		str = await rm.qrcode()
		qiniu.uploadStream c, {scope: "#{scope}:#{fn}"}, fn, qr.image str, (res)->
			log res

	sendPicTxt = (agt, txt, imgUrl, link)->
		try
			if _.isString agt
				agt = await pickRoom agt

			unless agt
				return

			if _.isString(txt) and txt.trim()
				await agt.say txt
			if imgUrl and await checkUrl(imgUrl)
				await dly(2)
				await agt.say FileBox.fromUrl cf._qnSetHref(imgUrl, 'rbImg'), 'pic.jpg'
			if link
				await dly(2)
				await agt.say link
		catch e
			log e

	makeAnnounce = (topic, text, pic, ul)->
		return unless topic
		unless _.isArray topic
			topic = [topic]
		for it in topic
			try
				rm = if _.isString it
					await pickRoom it
				else
					it
				if rm
					await dly()
					if text
						await dly(1)
						if rm.owner().name() is bot.userSelf().name()
							await rm.announce text
						else
							await rm.say text
					if pic
						await dly(1)
						await rm.say FileBox.fromUrl cf._qnSetHref(pic, 'rbImg'), 'pic.jpg'
					if ul
						await dly(1)
						await rm.say ul
			catch e
				log e

	groupSay = (topic, text, pic, ul)->
		return unless topic
		unless _.isArray topic
			topic = [topic]
		for it in topic
			try
				await sendPicTxt it, text, pic, ul
			catch e
				log e

	cleanRoom = (rName, ann, msg, remove)->
		if rm = await pickRoom rName
			if ann
				await rm.announce ann
			await dly(2)
			for it in await rm.memberAll()
				if remove
					await rm.del it
				else if it.name()!in cfg.wtAccount.initUser
					if it.friend()
						await rm.del it
					else
						log 'del: ' + it.name()
						await addFriend it, msg
			if remove
				await rm.quit()

	urlLink = (title, desc, thumb, url) ->
		new UrlLink
			title: title
			description: desc
			thumbnailUrl: thumb
			url: url

	miniBox = (title, desc, path, url)->
		new MiniProgram
			appid: cf.mini.appId
			description: desc
			pagePath: path
			thumbKey: ''
			thumbUrl: url
			title: title
			username: cf.mini.username

	findTag = (ct, tag)->
		try
			await dly()
			ts = await ct.tags()
			for t in ts
				if t.id is tag
					true
			false
		catch e
			log e
			false

	{
		pickContact
		pickContactId

		pickRoom

		fRoom
		fcRoom

		addFriend
		saveQrCode

		sendPicTxt
		makeAnnounce
		groupSay
		cleanRoom
		urlLink
		miniBox
		findTag

	}
