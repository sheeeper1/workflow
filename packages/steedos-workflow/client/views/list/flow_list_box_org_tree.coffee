Template.flow_list_box_org_tree.helpers


Template.flow_list_box_org_tree.onRendered ->

  showUserMainOrg = true
  showCompanyOnly = this.data?.showCompanyOnly
  if showCompanyOnly
    showUserMainOrg = false
  $(document.body).addClass('loading');
  # 防止首次加载时，获得不到node数据。
  # Steedos.subsSpace.subscribe 'organizations', Session.get("spaceId"), onReady: ->
  # this.autorun ()->
  #   if Steedos.subsSpace.ready("organizations")
  $("#steedos_contacts_org_tree").on('changed.jstree', (e, data) ->
        if data.selected.length
          Session.set("contact_showBooks", false)
          contacts_orgId = data.selected[0]
          if showUserMainOrg
            if contacts_orgId.split("userMainOrg_").length > 1
              contacts_orgId = contacts_orgId.split("userMainOrg_")[1]
          Session.set("contacts_orgId", contacts_orgId);
        return
      ).jstree
            core: 
                themes: { "stripes" : true, "variant" : "large" },
                data:  (node, cb) ->
                  contacts_orgId = node.id
                  if showUserMainOrg
                    if contacts_orgId.split("userMainOrg_").length > 1
                      contacts_orgId = contacts_orgId.split("userMainOrg_")[1]
                  cb(ContactsManager.getOrgNode(node, '', showUserMainOrg, true, showCompanyOnly));
                      
            plugins: ["wholerow", "search"]
  unless showCompanyOnly
    this.autorun ()->
      if Steedos.subsSpace.ready("address_groups")
        $("#books_tree").on('changed.jstree', (e, data) ->
              if data.selected.length
                Session.set("contact_showBooks", true)
                Session.set("contacts_groupId", data.selected[0]);
              return
            ).jstree
                  core: 
                      themes: { "stripes" : true },
                      data:  (node, cb) ->
                        Session.set("contacts_groupId", node.id);
                        cb(ContactsManager.getBookNode(node));
                            
                  plugins: ["wholerow", "search"]

  $(document.body).removeClass('loading');



Template.flow_list_box_org_tree.events
  'click #search-btn': (event, template) ->
    $('#steedos_contacts_org_tree').jstree(true).search($("#search-key").val());
    $('#books_tree').jstree(true).search($("#search-key").val());