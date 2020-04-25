{UrlLink, FileBox} = require('wechaty')

module.exports = (pre, app, bot, c, qiniu)->
	dly = util.dly

	{
		pickRoom
		addFriend
		cleanRoom
		makeAnnounce
		groupSay
		miniBox
		urlLink
		findTag
	} = require('./lib')(bot, qiniu)

	{
		bigGroup
		inGroup
		exGroup
	} = require './def'

	app.post "#{pre}evt/ctrl", (req, rsp)->
		if req.body.on
			bot.start()
		else
			bot.logout()
		rsp.send {}

	app.post "#{pre}evt/info", (req, rsp)->
		rsp.json {
			name: bot.userSelf().name()
			status: bot.logonoff()
			bigGroup,
			inGroup,
			exGroup
		}

	app.post "#{pre}evt/pubUserMsg", (req, rsp)->
		bo = req.body
		try
			for k, v of bo.ds
				if v and (u = await pickContact k)
					await dly()
					if bo.img and bo.url
						[title, desc, text] = v.split('||')
						link = new UrlLink
							title: title
							description: desc
							thumbnailUrl: cf._qnSetHref(bo.img, 'rbImg')
							url: bo.url
						await u.say link
						if text
							await dly(1)
							await u.say text
					else
						await u.say v
						bo.img and await u.say FileBox.fromUrl cf._qnSetHref(bo.img, 'rbImg')
		catch e
			log e
		rsp.json msg: 'ok'

	app.post "#{pre}evt/addGroup", (req, rsp)->
		bo = req.body
		rm = await pickRoom bo.group
		ulist = []
		if rm
			for it in await rm.memberAll()
				if it.friend()
					if bo.text
						await dly()
						await it.say bo.text
				else
					if bo.greeting
						await addFriend it, bo.greeting
					ulist.push it.name()
			rsp.json msg: ulist.join(',')

	app.post "#{pre}evt/mgmGroup", (req, rsp)->
		bo = req.body
		rm = await pickRoom bo.group
		if rm
			switch bo.type
				when 'addAll'
					for it in await rm.memberAll()
						unless it.friend()
							await addFriend it, bo.greeting
				when 'say'
					if bo.fmt is 'msgPic'
						await rm.say urlLink(bo.title, bo.greeting, bo.url, bo.img)
					else if bo.fmt is 'mini'
						await rm.say miniBox(bo.title, bo.greeting, bo.url, bo.img)
					else
						await groupSay rm, bo.greeting, bo.url
				when 'announce'
					await makeAnnounce rm, bo.greeting, bo.url
				when 'clean'
					if bo.group.endsWith '#'
						await cleanRoom rm, bo.ann, bo.greeting
				when 'del'
					if bo.group.endsWith '#'
						await cleanRoom rm, undefined, undefined, true

			rsp.json msg: 'ok'
		else
			rsp.json err: true

	app.post "#{pre}evt/mgmUser", (req, rsp)->
		bo = req.body
		ro = {}
		cList = await bot.Contact.findAll()
		switch bo.type
			when 'unfriend'
				ro.unList = []
				ro.tc = cList.length
				ro.nfc = 0
				ro.nc = 0
				for it in cList
					if it.friend()
						ro.unList.push
							name: it.name()
							wid: it.payload.weixin
					else if it.friend() is false
						ro.nfc++
					else
						ro.nc++
				ro.fc = ro.unList.length
			when 'tag'
				ro.tagList = []
				for it, idx in cList
					if idx > 500
						break
					if it.friend()
						if await findTag(it, bo.tag)
							tagList.push it
			when 'untagFriend'
				log 'untag'
			when 'del'
				log 'del'
		rsp.json ro