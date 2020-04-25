dly = util.dly

module.exports = (pre, app, bot, c, qiniu)->
	code = c.code
	{
		pickRoom
		fRoom
		fcRoom,
		addFriend
		pickContact
		pickContactId
		saveQrCode
		sendPicTxt
		makeAnnounce
		groupSay
		sendGroupMsg
		urlLink
		cleanRoom
		initList
	} = require('./lib')(c, bot, qiniu)

	{
		bigGroup
		inGroup
		exGroup
		smGroup

		evtGroup
		bjGroup
		drGroup
		testGroup
		petQr
	} = require('./def')

	picUrl = cf._qnSetHref(util.qnUrl('show', '8444042109959.jpg'))
	evtLink = urlLink 'PET Weekly Events', 'PET 一周活动汇总', picUrl, 'http://postenglishtime.com/wm'

	app.post "#{pre}evt/salonInfo", (req, rsp)->
		bo = req.body
		u = await bot.Contact.find name: bo.user.username
		if u
			ao = await dao.one code, 'agentOp', code: 'host salon'
			await u.say ao.content
			await u.say '请在下面公号里面输入：host，按照提示录入话题就行。个人信息一定要填写：行业，职位，个人介绍，这些会在周一时发公号，如果换照片，在个人照片里上传，取第一张。'
		rsp.json msg: 'ok'

	app.post "#{pre}evt/actPubNow", (req, rsp)->
		bo = req.body
		act = await dao.one code, 'activity', _id: oid(bo.aid)
		if act
			pic = util.refFile(act, 'ad')
			msg = act.adStr || act.brief
			if bo.group is 'allAnn'
				await makeAnnounce bigGroup, msg, pic
				await groupSay [inGroup..., exGroup...], msg, pic
			else if bo.group is 'all'
				await groupSay [bigGroup..., inGroup..., exGroup...], msg, pic
			else if bo.group
				await groupSay bo.group, msg, pic
		rsp.json msg: 'ok'

	app.post "#{pre}evt/pubNow", (req, rsp)->
		bo = req.body
		if bo.text
			if bo.ann is 'all'
				await makeAnnounce bigGroup, bo.brief, bo.pic
				await groupSay [inGroup..., exGroup...], bo.brief, bo.pic
			if bo.ann
				await makeAnnounce bo.ann.split(','), bo.text, bo.url
			if bo.say
				await groupSay bo.say.ann.split(','), bo.text, bo.url
			rsp.json msg: 'ok'

	app.post "#{pre}evt/toUser", (req, rsp)->
		bo = req.body
		ro = await pickContact bo.wtName
		await ro.say bo.msg
		rsp.json {msg: 'ok'}

	app.post "#{pre}evt/toHost", (req, rsp)->
		bo = req.body
		act = await dao.one code, 'activity', _id: oid(bo.aid)

		if act and act.master.length
			msg = act.master[0].username
			if u = await pickContact(msg)
				await u.say '请在合适的时间转发朋友圈或者邀请合适的朋友来参加。'
				await dly(2)
				await sendPicTxt u, act.brief, util.refFile(act, 'ad')
				ro = msg: 'done: ' + msg
			else
				ro = msg: 'no name: ' + msg
		rsp.json ro

	app.post "#{pre}evt/sideGroup", (req, rsp)->
		bo = req.body
		lrm = await pickRoom bo.group
		rm = await pickRoom bo.group + '#'
		if rm and lrm
			if bo.type is 'addAll'
				for it in await rm.memberAll()
					unless it.friend()
						await addFriend it, bo.greeting
			else if bo.type in ['addToGroup','addAndRemove']
				if bo.ann
					await rm.announce bo.ann
				for it in await rm.memberAll()
					if it.friend()
						if await lrm.has(it)
							if (bo.type is 'addAndRemove') and (it.name() !in initList)
								log 'del: ' + it.name()
								await dly()
								await rm.del it
						else
							log 'add: ' + it.name()
							if bo.greeting
								await it.say bo.greeting
								await dly()
							await lrm.add it
					else
						await addFriend it, bo.greeting
			else if bo.type is 'removeAll'
				for it in await rm.memberAll()
					if (it.name() !in initList)
						await dly()
						await rm.del it
			rsp.json msg: 'ok'
		else
			rsp.json err: true

	app.post "#{pre}evt/sendGM", (req, rsp)->
		bo = req.body
		rm = await pickRoom bo.gName
		if rm
			for it in await rm.memberAll()
				await dly()
				if it.friend()
					if bo.male and (it.gender() is bot.Contact.Gender.Male)
						await sendPicTxt it, bo.msg, bo.img

	saveActQrcode = (it)->
		if it.groupName
			rm = await fcRoom it.groupName, it
			if rm
				try
					scope = 'temp'
					fn = "activity_qr_#{util.randomChar(7)}.png"
					await saveQrCode rm, scope, fn
					$set =
						refFile: it.refFile
					$set.refFile.groupQrcode = [util.qnUrl(scope, fn, c)]
					await dao.update code, 'activity', {_id: it._id}, {$set}
					"done: #{it.title}\n"
				catch e
					log e
					"saveError: #{it.title}\n"
			else
				"no room: #{it.groupName}\n"
		else
			"no groupName: #{it.groupName}\n"

	app.post "#{pre}evt/genActQrcode", (req, rsp)->
		bo = req.body
		q = if bo.aid
			_id: oid(bo.aid)
		else
			$gte = new Date().monday()
			$lte = new Date($gte.getTime() + 7 * Date.day)
			startedDate: {$gte, $lte}
		acts = await dao.find code, 'activity', q
		msg = ''
		for it in acts
			msg += await saveActQrcode it
		rsp.json msg: msg

###############################################################

	AgentOp = gEnt(c.code, 'agentOp')

	nf =
		greet: await AgentOp.findOne(code: 'nfGreet')
		accept: await AgentOp.findOne(code: 'nfAccept')
		event: await AgentOp.findOne(code: 'nfEvent')
		mini: await AgentOp.findOne(code: 'nfMini')
		groupRule: await AgentOp.findOne(code: 'nfGroupRule')
		pet: await AgentOp.findOne(code: 'subscribe')
		hostSalon: await AgentOp.findOne(code: 'host salon')
		addTopic: await AgentOp.findOne(code: 'host')


	checkAndAddGroup = (group, greeting, clean)->
		lrm = await pickRoom group
		rm = await pickRoom group + '#'
		if rm and lrm
			newList = []
			oldList = []
			for it in await rm.memberAll()
				await it.sync()
				if it.friend()
					await dly()
					if await lrm.has(it)
						if clean and (it.name() !in initList)
							log 'del: ' + it.name()
							await rm.del it
					else
						log 'add: ' + it.name()
						await it.say '您好，感谢您来参加活动，现在邀请您进入我们的活动大群：）'
						await dly(2)
						await lrm.add it
						oldList.push it.name()
				else
					if greeting
						await addFriend it, greeting
					newList.push it.name()

	bot.on 'friendship', (friendship)->
		try
			switch friendship.type()
				when bot.Friendship.Type.Receive
					log 'accept friendship!'
					await friendship.accept()
					await sendPicTxt friendship.contact(), nf.greet.content, nf.greet.imgUrl
					tt = friendship.hello()
					if /豆瓣/.test(tt) or /推荐/.test(tt) or /参加/.test(tt)
						await evtRm.add friendship.contact()
					break
				when bot.Friendship.Type.Confirm
					log 'Friendship Confirm'
				when bot.Friendship.Type.Verify
					log 'Friendship Verify'
					break
		catch e
			log e

	uSession = null

	Ty = bot.Message.Type

	bot.on 'message', (m)->
		return if m.self()

		if m.age() > 90
			return

		aos = global.aos
		try
			contact = m.from()
			text = m.text()
			room = m.room()
			if contact
				username = contact.name()
			if room
				topic = await room.topic()
				if topic is testGroup
					log("Room: #{topic} Contact: #{username} Content: #{text}")
				else if topic is "GroupName"
					path = util.sPath(code) + '/gShare/'
					if username in ['userList']
						nfstr = "gs6_#{Date.now()}_#{contact.payload.weixin || contact.id}"
						if m.type() in [Ty.Attachment, Ty.Video, Ty.Audio, Ty.Image]
							fBox = await m.toFileBox()
							fn = "#{nfstr}.#{fBox.name.split('.')[1]}"
							fp = path + fn
							await fBox.toFile(fp)
							qiniu.upload c, {scope: 'temp'}, fn, fp, ->
						else if m.type() in [Ty.Text, Ty.Url]
							qiniu.put c, {scope: 'temp'}, "#{nfstr}.txt", text, ->
				else if topic is smGroup
					await addFriend(contact)
			else
				if apid = aos[text]
					apd = await dao.one code, 'agentOp', _id: apid
					cc = if apd.type is 'page'
						urlLink apd.title, apd.help, apd.imgUrl, apd.content
					else
						apd.content
					await m.say cc
					return

				nob = if /活动报名/.test(text) or /报名活动/.test(text)
					nf.event
				else if /小程序/.test(text)
					nf.mini
				else if /群管理/.test(text)
					nf.groupRule
				else if /后英语时代/.test(text)
					nf.pet
				else
					null

				if nob
					await sendPicTxt m, nob.content, nob.imgUrl
					return

				if /客服/.test(text)
					await m.say await pickContact(csUser)

				else if /活动群/.test(text)
					await evtRm.add contact

				else if /您好/.test(text) or /你好/.test(text) or /hi/.test(text)
					await m.say 'hi~, 我现在比较忙，请留言，稍后回复您。'

				else if /活动信息/.test(text)
					await m.say evtLink

				else if /朗读计划/.test(text)
					await drRm.add contact

				else if /aiarm/.test(text)
					uSession = "s::#{username}"

				else if /toOut/.test(text)
					await bot.logout()

				if uSession
					if (uSession is "ss::#{username}") and (cc = await pickContact(initList[1]))
						m.forward cc
						uSession = null
		catch e
			log e

	require('./timer')(c, bot, qiniu)

	if bot.logonoff()
		log 'wechaty start...'
		try
			await dly()
			evtRm = await pickRoom evtGroup
			drRm = await pickRoom drGroup
			smRm = await pickRoom smGroup
			smRm.on 'join', (inviteeList, inviter)->
				log 'sm join: ' + inviter.name()
				if inviter.name() is cfg.wtAccount.customerService
					for it in inviteeList
						if it.friend()
							it.say '您好，我们的活动需要提前交费，有什么问题，请给我留言。'
						else
							await addFriend it, '您好，感谢报名我们的活动，活动需要提前交费'