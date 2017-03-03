Template.masterHeader.helpers

	displayName: ->

		if Meteor.user()
			return Meteor.user().displayName()
		else
			return " "
	
	avatar: () ->
		return Meteor.user()?.avatar

	avatarURL: (avatar,w,h,fs) ->
		return Steedos.absoluteUrl("avatar/#{Meteor.userId()}?w=#{w}&h=#{h}&fs=#{fs}&avatar=#{avatar}");

	spaceId: ->
		return Steedos.getSpaceId()

	workflowApp: ->
		return db.apps.findOne({_id:"workflow"})

	cmsApp: ->
		return db.apps.findOne({_id:"cms"})



Template.masterHeader.events

	'click .main-header .logo': (event) ->
		Modal.show "app_list_box_modal"

	'click .steedos-help': (event) ->
		Steedos.showHelp();

	'click .btn-logout': (event,template) ->
		$("body").addClass("loading")