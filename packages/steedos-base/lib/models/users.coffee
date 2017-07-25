db.users = Meteor.users;

db.users.allow
	# Allow user update own profile
	update: (userId, doc, fields, modifier) ->
		if userId == doc._id
			return true

db.users._simpleSchema = new SimpleSchema
	name: 
		type: String,
	username: 
		type: String,
		unique: true,
		optional: true
	steedos_id: 
		type: String,
		optional: true
		unique: true,
		autoform: 
			type: "text"
			readonly: true
	company: 
		type: String,
		optional: true,
	mobile: 
		type: String,
		optional: true,
		autoform:
			if Steedos.isPhoneEnabled()
				readonly: true
			else
				type: "hidden"
	work_phone:
		type: String,
		optional: true
	position:
		type: String,
		optional: true
	locale: 
		type: String,
		optional: true,
		allowedValues: [
			"en-us",
			"zh-cn"
		],
		autoform: 
			type: "select",
			options: [{
				label: "简体中文",
				value: "zh-cn"
			},
			{
				label: "English",
				value: "en-us"
			}]
	
	email_notification:
		type: Boolean
		optional: true

	primary_email_verified:
		type: Boolean
		optional: true
		autoform: 
			omit: true
	last_logon:
		type: Date
		optional: true
		autoform: 
			omit: true
	is_cloudadmin:
		type: Boolean
		optional: true
		autoform: 
			omit: true
	is_deleted:
		type: Boolean
		optional: true,
		autoform:
			omit: true
	avatar: 
		type: String
		optional: true

if Meteor.isClient
	db.users._simpleSchema.i18n("users")

db.users.helpers
	spaces: ->
		spaces = []
		sus = db.space_users.find({user: this._id}, {fields: {space:1}})
		sus.forEach (su) ->
			spaces.push(su.space)
		return spaces;

	displayName: ->
		if this.name 
			return this.name
		else if this.username
			return this.username
		else if this.emails and this.emails[0]
			return this.emails[0].address


if Meteor.isServer

		
	db.users.checkEmailValid = (email) ->
		existed = db.users.find 
			"emails.address": email
		if existed.count()>0
			throw new Meteor.Error(400, "users_error_email_exists");

	db.users.checkUsernameValid = (username) ->
		existed = db.users.find 
			"username": username
		if existed.count()>0
			throw new Meteor.Error(400, "users_error_username_exists");

	db.users.before.insert (userId, doc) ->

		doc.created = new Date();
		doc.is_deleted = false;
		if userId
			doc.created_by = userId;

		if doc.services?.google
			if doc.services.google.email && !doc.emails
				doc.emails = [{
					address: doc.services.google.email,
					verified: true
				}]
			if doc.services.google.picture
				doc.avatarUrl = doc.services.google.picture

		if doc.services?.facebook
			if doc.services.facebook.email && !doc.emails
				doc.emails = [{
					address: doc.services.facebook.email,
					verified: true
				}]

		if (doc.emails && !doc.steedos_id)
			if doc.emails.length>0
				doc.steedos_id = doc.emails[0].address

		if (doc.profile?.name && !doc.name)
			doc.name = doc.profile.name

		if (doc.profile?.locale && !doc.locale)
			doc.locale = doc.profile.locale

		if (doc.profile?.company && !doc.company)
			doc.company = doc.profile.company

		if (doc.profile?.mobile && !doc.mobile)
			doc.mobile = doc.profile.mobile

		if !doc.steedos_id && doc.username
			doc.steedos_id = doc.username 

		if !doc.name
			doc.name = doc.steedos_id.split('@')[0]

		# if !doc.username
		# 	doc.username = doc.steedos_id.replace("@","_").replace(".","_")

		# for steedos chat
		if !doc.type
			doc.type = "user"
		if !doc.active
			doc.active = true
		if !doc.roles
			doc.roles = ["user"]

		if !doc.utcOffset
			doc.utcOffset = 8

		_.each doc.emails, (obj)->
			db.users.checkEmailValid(obj.address);
		

	db.users.after.insert (userId, doc) ->
		if !(doc.spaces_invited?.length>0)
			db.spaces.insert
				name: doc.name + " " + trl("space")
				owner: doc._id
				admins: [doc._id]

		try
			if !doc.services || !doc.services.password || !doc.services.password.bcrypt
				# 发送让用户设置密码的邮件
				Accounts.sendEnrollmentEmail(doc._id, doc.emails[0].address)
		catch e
			console.log "after insert user: sendEnrollmentEmail, id: " + doc._id + ", " + e


	db.users.before.update  (userId, doc, fieldNames, modifier, options) ->
		if modifier.$unset && modifier.$unset.steedos_id == ""
			throw new Meteor.Error(400, "users_error_steedos_id_required");

		modifier.$set = modifier.$set || {};

		if doc.steedos_id && modifier.$set.steedos_id
			if modifier.$set.steedos_id != doc.steedos_id
				throw new Meteor.Error(400, "users_error_steedos_id_readonly");

		if userId
			modifier.$set.modified_by = userId;

		if modifier.$set['phone.verified'] is true
			# substring(3) 是为了去掉 "+86"
			modifier.$set.mobile = doc.phone.number.substring(3)
		modifier.$set.modified = new Date();


	db.users.after.update (userId, doc, fieldNames, modifier, options) ->
		modifier.$set = modifier.$set || {};

		console.log "db.users.after.update==============2"
		console.log "db.users.after.update,modifier.$set#{JSON.stringify(modifier.$set)}"
		console.log "db.users.after.update,modifier.$unset：#{JSON.stringify(modifier.$unset)}"

		user_set = {}
		user_unset = {}
		if modifier.$set.name
			user_set.name = modifier.$set.name
		if modifier.$set.position
			user_set.position = modifier.$set.position
		if modifier.$set.work_phone
			user_set.work_phone = modifier.$set.work_phone
		if modifier.$set.mobile
			user_set.mobile = modifier.$set.mobile

		if modifier.$unset
			user_unset.name = modifier.$unset.name
			user_unset.position = modifier.$unset.position
			user_unset.work_phone = modifier.$unset.work_phone
			user_unset.mobile = modifier.$unset.mobile

		console.log "db.users.after.update==============3"
		console.log "user_set:#{JSON.stringify user_set}"
		console.log "user_unset:#{JSON.stringify user_unset}"
		# console.log "db.users.after.update,doc.mobile：#{doc.mobile}"
		# console.log "db.users.after.update,modifier.$set.mobile：#{modifier.$set.mobile}"
		# console.log "db.users.after.update,modifier.$unset.mobile：#{modifier.$unset.mobile}"
		# if doc.mobile
		# 	user_set.mobile = doc.mobile
		# else
		# 	user_unset.mobile = ""

		# 更新users表中的相关字段，所有工作区信息同步
		if not _.isEmpty(user_set)
			db.space_users.direct.update({user: doc._id}, {$set: user_set}, {multi: true})
		if not _.isEmpty(user_unset)
			db.space_users.direct.update({user: doc._id}, {$unset: user_unset}, {multi: true})


	db.users.before.remove (userId, doc) ->
		throw new Meteor.Error(400, "users_error_cloud_admin_required");


			
	Meteor.publish 'userData', ->
		unless this.userId
			return this.ready()


		db.users.find this.userId,
			fields:
				steedos_id: 1
				name: 1
				company: 1
				work_phone: 1
				position: 1
				mobile: 1
				locale: 1
				username: 1
				utcOffset: 1
				settings: 1
				is_cloudadmin: 1
				email_notification: 1,
				avatar: 1

if Meteor.isServer
	db.users._ensureIndex({
		"is_deleted": 1
	},{background: true})

	db.users._ensureIndex({
		"email": 1
	},{background: true})

	db.users._ensureIndex({
		"is_deleted": 1
		"email": 1
	},{background: true})

	db.users._ensureIndex({
		"_id": 1
		"created": 1
	},{background: true})

	db.users._ensureIndex({
		"_id": 1
		"created": 1,
		"modified": 1
	},{background: true})

	db.users._ensureIndex({
		"primary_email_verified": 1,
		"locale": 1,
		"name": 1,
		"_id": 1,
		"mobile": 1,
		"company": 1
	},{background: true})

	db.users._ensureIndex({
		"primary_email_verified": 1,
		"locale": 1,
		"name": 1,
		"_id": 1,
		"mobile": 1,
		"company": 1,
		"created": 1
	},{background: true})

	db.users._ensureIndex({
		"primary_email_verified": 1,
		"locale": 1,
		"name": 1,
		"_id": 1,
		"mobile": 1,
		"company": 1,
		"created": 1,
		"last_logon": 1
	},{background: true})

	db.users._ensureIndex({
		"imo_uid": 1
	},{background: true})

	db.users._ensureIndex({
		"qq_open_id": 1
	},{background: true})

	db.users._ensureIndex({
		"created": 1
	},{background: true})

	db.users._ensureIndex({
		"last_logon": 1
	},{background: true})

	db.users._ensureIndex({
		"created": 1,
		"modified": 1
	},{background: true})

	db.users._ensureIndex({
		"name": 1
	},{background: true})

	db.users._ensureIndex({
		"lastLogin": 1
	},{background: true})

	db.users._ensureIndex({
		"status": 1
	},{background: true})

	db.users._ensureIndex({
		"active": 1
	},{background: true})

	db.users._ensureIndex({
		"type": 1
	},{background: true})

	db.users._ensureIndex({
		"steedos_id": 1
	},{background: true})
