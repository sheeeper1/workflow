Template.cf_organization_list.helpers 


Template.cf_organization_list.onRendered ->
  $(document.body).addClass('loading');
  # 防止首次加载时，获得不到node数据。
  # Steedos.subsSpace.subscribe 'organizations', Session.get("spaceId"), onReady: ->
  this.autorun ()->
    if Steedos.subsSpace.ready("organizations")
      # console.log "loaded_organizations ok...";
      $("#cf_organizations_tree").on('changed.jstree', (e, data) ->
            # console.log(data);
            if data.selected.length
              # console.log 'The selected node is: ' + data.instance.get_node(data.selected[0]).text
              Session.set("cf_selectOrgId", data.selected[0]);
              Session.set("cf_orgAndChild", CFDataManager.getOrgAndChild(Session.get("cf_selectOrgId")));
            return
          ).jstree
                core: 
                    themes: { "stripes" : true },
                    data:  (node, cb) ->
                      Session.set("cf_selectOrgId", node.id);
                      cb(CFDataManager.getNode(node));
                      Session.set("cf_orgAndChild", CFDataManager.getOrgAndChild(Session.get("cf_selectOrgId")));
                          
                plugins: ["wholerow"]

      $(document.body).removeClass('loading');



Template.cf_organization_list.events