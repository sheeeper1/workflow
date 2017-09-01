Template.org_main_mobile.helpers
	subsReady: ->
		return Steedos.subsAddressBook.ready() and Steedos.subsSpace.ready();

	isShowOrg: ->
		unless Steedos.isNotSync()
			return false
		#在个人联系人里不需要判断管理员的权限，在组织架构中需要判断是否有管理员权限
		if /^\/contacts\b/.test(Session.get("router-path"))
			return  true
		else if Steedos.isSpaceAdmin()
			return  true

	data: ->
		return {isDisabled: true}

	getOrgName: ()->
		return SteedosDataManager.organizationRemote.findOne({_id:Session.get("contacts_orgId")},{fields:{name: 1}})?.name;

	title: ()->
		currentOrgId = Session.get('contacts_org_mobile')
		currentOrg = db.organizations.findOne({ _id: currentOrgId })
		if currentOrg
			return currentOrg.name
		else
			return Steedos.spaceName()

	preOrgId: ()->
		return Session.get('contacts_pre_org_mobile')

	selector: ->

		is_within_user_organizations = ContactsManager.is_within_user_organizations();

		hidden_users = Meteor.settings.public?.contacts?.hidden_users || []

		setting = db.space_settings.findOne({space: Session.get("spaceId"), key: "contacts_hidden_users"})

		setting_hidden_users = setting?.values || []

		hidden_users = hidden_users.concat(setting_hidden_users)

		query = {space: Session.get("spaceId"), user: {$nin: hidden_users}}

		if !Session.get("contact_list_search")
			orgId = Session.get("contacts_org_mobile");
			query.organizations = {$in: [orgId]};
		else
			if is_within_user_organizations
				orgs = db.organizations.find().fetch().getProperty("_id")

			if Session.get("contacts_org_mobile")
				orgs = [Session.get("contacts_org_mobile")]

			orgs_childs = SteedosDataManager.organizationRemote.find({parents: {$in: orgs}}, {
				fields: {
					_id: 1
				}
			});

			orgs = orgs.concat(orgs_childs.getProperty("_id"))

			query.organizations = {$in: orgs};

		if !Session.get('contacts_is_org_admin')
			query.user_accepted = true
		return query;

	selectorForOrgs: ->
		currentOrgId = Session.get('contacts_org_mobile')
		spaceId = Steedos.spaceId()
		if currentOrgId
			# Tabular自带的订阅因为没用SubsManager的subscribe而用的是Meteor.subscribe，造成订阅的缓存机制没有效果。
			# 所以这里先写成订阅自己及子组织，以后Tabular自带的订阅的缓存BUG解决后再去掉订阅自己，只订阅子组织就行
			selector =
				$or:[
					$and:[{
						space: spaceId
						parent: currentOrgId
						hidden: { $ne: true }
					}],
					{ _id: currentOrgId }
				]
			console.log "selector:#{JSON.stringify selector}",selector
		else
			isWithinUserOrganizations = ContactsManager.is_within_user_organizations();
			if isWithinUserOrganizations
				userId = Meteor.userId()
				uOrgs = db.organizations.find({ space: spaceId, users: userId },fields: {parents: 1}).fetch()
				_ids = uOrgs.getProperty('_id')
				orgs = _.filter uOrgs, (org) ->
					parents = org.parents or []
					return _.intersection(parents, _ids).length < 1
				selector = { space: spaceId, _id: { $in: orgs.getProperty('_id') } }
			else
				selector = { space: spaceId, is_company: true }
		console.log "selector2:#{JSON.stringify selector}",selector
		return selector

Template.org_main_mobile.onCreated ->
	spaceId = Steedos.spaceId()
	isWithinUserOrganizations = ContactsManager.is_within_user_organizations()
	unless isWithinUserOrganizations
		rootOrg = db.organizations.findOne({ space: spaceId, is_company: true })
		if rootOrg
			Session.set('contacts_org_mobile', rootOrg._id)

Template.org_main_mobile.onRendered ->
		if Steedos.isNotSync()
			TabularTables.steedosContactsOrganizations.customData = @data
			TabularTables.steedosContactsBooks.customData = @data
			
			ContactsManager.setContactModalValue(@data.defaultValues);

			ContactsManager.handerContactModalValueLabel();
			$("#contact_list_load").hide();
		else
			paths = FlowRouter.current().path.match(/\/[^\/]+/)
			if paths?.length
				rootPath = paths[0]
			else
				rootPath = "/admin"
			if rootPath == "/contacts"
				rootPath = "/contacts/books"
			FlowRouter.go rootPath
			toastr.error(t("contacts_organization_permission_alert"));

Template.org_main_mobile.events
	'click .datatable-mobile-organizations tbody tr[data-id]': (event, template)->
		currentOrgId = Session.get('contacts_org_mobile')
		Session.set('contacts_pre_org_mobile', currentOrgId)
		Session.set('contacts_org_mobile', event.currentTarget.dataset.id)
		# Modal.show('steedos_contacts_space_user_info_modal', {targetId: event.currentTarget.dataset.id, isEditable: false})

	'click .btn-back': (event, template)->
		preOrgId = Session.get('contacts_pre_org_mobile')
		Session.set('contacts_org_mobile', preOrgId)
		Session.set('contacts_pre_org_mobile', null)
