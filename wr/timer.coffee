schedule = require('node-schedule')

cfg = require '../cfg'

readEGreet = (d)->
	switch d.getDay()
		when 1
			null
		when 2
			'晚上好，今天的朗读内容有什么问题吗？欢迎在群里讨论哦~'
		when 3
			'Good evening. Any questions about today\'s reading? Welcome to discuss in the group~'
		when 4
			'晚上好，今天的朗读你完成了吗？友情提示：读完记得听听自己的朗读，对比一下原声，这是朗读小程序的正确使用方法'
		when 5
			'周末快乐~ 睡觉前记得完成今天的朗读内容哦，晚安'
		when 6
			'Reading Tips: Listen to your own reading and compare to the original, this is the correct way to use this mini app.'
		when 0
			null

readMGreet = (d)->
	switch d.getDay()
		when 1
			null
		when 2
			"Morning, dear friend, practice makes perfect! Let's start to read aloud."
		when 3
			"坚持就是胜利，想要提升口语就要多多练习，加油~"
		when 4
			"Morning, dear friend, persistence is victory! Let's continue to exercise the English oral muscles together."
		when 5
			"TGIF, finally the weekend is coming, today's English sentence is very interesting, don't miss it."
		when 6
			"Morning, dear friend, Wish you have a great weekend and don't forget to read English aloud:)"
		else
			"周末愉快，今天是【PET一周朗读计划】最后一天，除了好好休息，别忘完成英文朗读哦~"

readGreet = ->
	d = new Date
	h = d.getHours()
	if h < 13
		readMGreet d
	else
		readEGreet d

module.exports = (c, bot, qiniu) ->
	return if bot.userSelf().name() isnt cfg.wtAccount.customerService

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

	dly = util.dly

	picUrl = cf._qnSetHref(util.qnUrl('show', '8444042109959.jpg'))
	evtLink = urlLink 'PET Weekly Events', 'PET 一周活动汇总', picUrl, 'http://postenglishtime.com/wm'

	sendReadMsg = (gp, text)->
		d = new Date()
		dr = await dao.one code, 'dayRead', dateStr: d.pattern('yyyy-MM-dd')
		if dr
			await groupSay gp, text, cf._qnSetEnt(dr, 'share', 0, 'rbImg')
			if dr.shareStr
				await groupSay testGroup, dr.shareStr

	inThatDay = (d = new Date())->
		d.setHours 5
		$gte = d
		$lte = new Date d.getTime()
		$lte.setHours 23, 30, 0
		{$gte, $lte}

	todayEvt = (d = new Date() , cat)->
		q =
			startedDate: inThatDay(d)
			status: 2
		if cat
			q.cat = cat
		p =
			sort:
				startedDate: 1
		await dao.find code, 'activity', q, p

	sendAggEvt = (gp, acts)->
		if acts.length > 0
			adStr = "PET 本#{new Date(acts[0].startedDate).pattern('EE')}活动快讯\n\n"
			for it in acts
				adStr += "【#{new Date(it.startedDate).pattern('HH:mm')}-#{new Date(it.endDate).pattern('HH:mm')}】#{it.adStr || it.brief ||it.title}\n\n"
			adStr += '活动详情请点击: \nhttp://postenglishtime.com/wm'
			adStr += '\n\n-- PET后英语时代，聊英文 交朋友 分享你的经历'
			await groupSay gp, adStr

	schedule.scheduleJob '0 0 7 * * 0-6', -> # morning
		d = new Date()
		if d.getDay() is 1 # send reading group
			q =
				cat: 'weekRead'
			p =
				limit: 2
				sort:
					startedDate: -1
			[thisWeek, lastWeek] = await dao.find code, 'activity', q, p
			rd = await dao.one code, 'readReport',
				'nextAct._id': thisWeek._id
			if rd and rd.mondayMsg
				iu = util.qnUrl('temp', "activity_ad_#{thisWeek._id}.jpg", c)
				ul = urlLink rd.title, rd.subTitle, cf._qnSetHref(util.refFile(lastWeek), 'wideFix'), "http://postenglishtime.com/readReport/#{rd._id}"
				await makeAnnounce drGroup, rd.mondayMsg, iu, ul
				omsg = "新鲜出炉的【PET一周朗读计划】报告，里面有小伙伴的精彩朗读，快来听一下吧[ThumbsUp]\n\n拥有正确的发音习惯需要坚持有反馈的练习，欢迎朋友们参加我们的PET一周朗读计划，让我们一起读英文，练发音，涨知识，最后还能赢大奖哦🎁 \n\n周一的英文选段总是满满正能量，让我们开始今天的英文朗读吧[KeepFighting]"
				allGroup = [bigGroup..., inGroup...]
				allGroup.remove drGroup
				await groupSay allGroup, omsg, null, ul
				if thisWeek.adStr
					await sendPicTxt testGroup, null, thisWeek.adStr

		await sendReadMsg bigGroup, readGreet()
		await sendReadMsg inGroup
		await sendReadMsg exGroup

	schedule.scheduleJob '0 30 12 * * 0-6', ->
		da = new Date()
		dstr = new Date().monday().pattern('yyyy_MM_dd')
		all = [bigGroup..., exGroup..., inGroup...]

		switch da.getDay()
			when 0
				for act in await todayEvt(new Date().addDays(1), 'weekRead')
					await dly()
					await groupSay all, act.adStr, util.refFile(act, 'ad')
			when 1
				rm = await pickRoom smGroup
				if rm
					sgn = await dao.one code, 'agentOp', code: 'smGroupNotice'
					await makeAnnounce rm, sgn.content, petQr
					await dly(1)
					await saveQrCode rm, 'temp', "smp_#{dstr}.jpg"

				ao = await dao.one code, 'agentOp', code: 'newFriends'
				if ao
					await dly()
					await makeAnnounce evtGroup, ao.content, petQr

				await dly()
				sendAggEvt all, await todayEvt da.addDays(2)
			when 2
				await dly()
				sy = await dao.one code, 'syncEntity', title: "evt #{new Date().monday().pattern('yyyy-MM-dd')}"
				if sy
					await makeAnnounce bigGroup, sy.weekday, null, evtLink
					await dly()
					await groupSay [inGroup..., exGroup...], sy.weekday, null, evtLink
			when 3
				log '周五'
				sendAggEvt all, await todayEvt da.addDays(2)
			when 4
				log '周六'
				sendAggEvt all, await todayEvt da.addDays(2)
			when 5
				sy = await dao.one code, 'syncEntity', title: "evt #{new Date().monday().pattern('yyyy-MM-dd')}"
				if sy
					await makeAnnounce bigGroup, sy.weekend, null, evtLink
					await dly()
					await groupSay [inGroup..., exGroup...], sy.weekend, null, evtLink
			when 6
				sendAggEvt all, await todayEvt da.addDays(1)

		acts = await dao.find code, 'activity',
			pubTime: new Date().pattern('yyyy-MM-dd')
			groupName:
				$exists: true
			status: 2
		for it in acts
			pic = util.refFile(it, 'ad')
			await makeAnnounce it.groupName, it.adStr || it.brief, pic

		for act in await todayEvt() when act.groupName and act.remindMsg
			await dly()
			if rm = await fRoom act.groupName
				actLink = urlLink  act.title, (act.adStr || act.brief), util.refFile(act, 'ad'), "http://postenglishtime.com/newAct/activity/#{act._id}"
				await makeAnnounce rm, act.remindMsg, null, actLink

	schedule.scheduleJob '0 0 22 * * 0-6', ->
		d = new Date()
		switch d.getDay()
			when 1
				await cleanRoom smGroup, '您好，我是PET后英语时代的官方客服，感谢参加我们的活动', 'del'
				await makeAnnounce smGroup, 'Hi您好，请添加我的微信，我们的活动需要提前交费，有什么问题可以给我留言。谢谢😀'

				rp = await dao.one code, 'activity',
					cat: 'weekRead'
					sort:
						startedDate: -1
				if rp and rp.attention
					msg = 'Hi您好, 感谢您参加【PET一周朗读计划】，请留意我们的评分规则[Smart]：\n\n'
					msg += rp.attention.join('\n\n')
					msg += "\n\n今天是第一天，万事开头难，记得完成今天的朗读内容哦[KeepFighting]，晚安[Moon]"
					await makeAnnounce drGroup, msg

			when 2
				acts = await dao.find code, 'activity',
					dbId:
						$exists: true
					startedDate:
						$gt: new Date().monday()
				cms = await dao.find code, 'codeMap',
					key: 'dbr'
					status: 2
				cms = _.shuffle cms
				for it in acts
					await app.dbReg cms, it.dbId
			when 4
				nd = new Date().monday().addDays(7)
				wp = await dao.one code, 'weekPlan', dateStr: nd.pattern('yyyy-MM-dd')
				unless wp
					ob =
						dateStr: nd.pattern('yyyy-MM-dd')
						weekGoal: 'set this week goal plz'
					q =
						weekDay: 'all'
					p =
						projection: queryUtil.attrs 'title,description,minute'
						sort:
							row: -1
					alll = await dao.find code, 'dailyWork', q, p
					for it in [1..7]
						q =
							weekDay: it + ''
						ob["d#{it}"] = alll.concat(await dao.find code, 'dailyWork', q, p)
					await dao.save code, 'weekPlan', ob

				rp = await dao.one code, 'activity',
					cat: 'weekRead'
					sort:
						startedDate: -1

				# read plan
				if rp and rp.startedDate < new Date()
					[p1, p2] = rp.title.split('.')
					rp.title = [p1, +p2 + 1].join('.')
					delete rp._id
					rp.startedDate = rp.startedDate.addDays(7)
					rp.endDate = rp.endDate.addDays(7)
					rp.viewCount = 0
					rp.refFile =
						head: rp.refFile.head

					rp = await dao.save code, 'activity:title', rp
					rp = rp[0]

					catStr =
						1: 'wisdomWord'
						2: 'series'
						3: 'news'
						4: 'series'
						5: 'poem'
						6: 'movie'
						7: 'book'

					rp = _.pick rp, 'title', '_id'
					nd = new Date().monday().addDays(6)
					for it in [1..7]
						nd.addDays(1)
						ds = nd.pattern('yyyy-MM-dd')
						cr = await dao.one code, 'dayRead', dateStr: ds
						unless cr
							await dao.save code, 'dayRead',
								dateStr: ds
								activity: rp
								cat: catStr[it]
								status: 2
								level: if it is 1 then '1' else '3'
			when 0
				await makeAnnounce drGroup, "Hi小伙伴们，本周【PET朗读计划】马上就要结束了，评选会在凌晨进行，请还没有完成朗读内容的小伙伴们抓紧时间了！"
				nd = new Date()
				q =
					status: 2
					dateStr:
						$gte: nd.monday().pattern('yyyy-MM-dd')
						$lte: nd.sunday().pattern('yyyy-MM-dd')
				rs = await dao.find code, 'dayRead', q
				rm = await pickRoom drGroup
				for it in rs
					await sendPicTxt rm, null, util.refFile(it, 'share')

		await sendReadMsg bigGroup, readGreet()

		for act in await todayEvt()
			await dly()
			if act.groupName
				rm = await fRoom act.groupName
				if rm
					if act.master.length
						hName = act.master[0].username
					if (tpp = await rm.topic()) and tpp.endsWith '#'
						if act.cat is 'salon'
							if host = await pickContact hName
								await host.say "hi #{hName}，感谢晚上精彩的分享，有时间写一下主持人总结吧，之后会生成一份活动回顾，配上照片和视频。页面里面还有feedback选项，可以看到别人给你的反馈。\nhttp://postenglishtime.com/newAct/activity/#{act._id}#!/enroll/cs"
								await dly()
						if act.endMsg
							await makeAnnounce rm, act.endMsg.replaceAll('###', hName), petQr