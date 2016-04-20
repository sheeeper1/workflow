Busboy = Npm.require('busboy');
Fiber = Npm.require('fibers');

JsonRoutes.parseFiles = (req, res, next) ->
    files = []; # Store files in an array and then pass them to request.
    image = {}; # crate an image object

    if (req.method == "POST") 
      busboy = new Busboy({ headers: req.headers });
      busboy.on "file",  (fieldname, file, filename, encoding, mimetype) ->
        image.mimeType = mimetype;
        image.encoding = encoding;
        image.filename = filename;

        # buffer the read chunks
        buffers = [];

        file.on 'data', (data) ->
          buffers.push(data);

        file.on 'end', () ->
          # concat the chunks
          image.data = Buffer.concat(buffers);
          # push the image object to the file array
          files.push(image);


      busboy.on "field", (fieldname, value) ->
        req.body[fieldname] = value;

      busboy.on "finish",  () ->
        # Pass the file array together with the request
        req.files = files;

        Fiber ()->
          next();
        .run();
      
      # Pass request to busboy
      req.pipe(busboy);
    
    else
      next();
    

#JsonRoutes.Middleware.use(JsonRoutes.parseFiles);

JsonRoutes.add "post", "/s3/",  (req, res, next) ->

  JsonRoutes.parseFiles req, res, ()->
    collection = cfs.instances

    if req.files and req.files[0]

      newFile = new FS.File();
      newFile.attachData req.files[0].data, {type: req.files[0].mimeType}, (err) ->
        newFile.name(req.files[0].filename);

        collection.insert newFile,  (err, fileObj) ->
          resp = {
            version_id: fileObj._id
            size: fileObj.size 
          };
          res.end(JSON.stringify(resp));
          return
    else
      res.statusCode = 500;
      res.end();

   
JsonRoutes.add "delete", "/s3/",  (req, res, next) ->

  JsonRoutes.parseFiles req, res ()->

    collection = cfs.instances

    id = req.query.version_id;
    if id
      file = collection.findOne({ _id: id })
      if file
        file.remove()
        resp = {
          status: "OK"
        }
        res.end(JSON.stringify(resp));
        return

    res.statusCode = 404;
    res.end();

   
JsonRoutes.add "get", "/s3/",  (req, res, next) ->

  id = req.query.version_id;

  res.statusCode = 302;
  res.setHeader "Location", "/api/files/instances/" + id + "?download=1"
  res.end();


JsonRoutes.add "post", "/s3/upgrade",  (req, res, next) ->
  console.log("/s3/upgrade")

  fs = Npm.require('fs')
  mime = Npm.require('mime')

  root_path = Meteor.settings.fakes3_root
  console.log(root_path)
  collection = cfs.instances

  # 遍历instance 拼出附件路径 到本地找对应文件 分两种情况 1./filename_versionId 2./filename；
  deal_with_version = (root_path, space, ins_id, version, attach_filename) ->
    _rev = version._rev
    created_by = version.created_by
    approve = version.approve
    filename = version.filename || attach_filename;
    mime_type = mime.lookup(filename)
    new_path = root_path + "/spaces/" + space + "/workflow/" + ins_id + "/" + filename + "_" + _rev
    old_path = root_path + "/spaces/" + space + "/workflow/" + ins_id + "/" + filename

    readFile = (full_path) ->
      fs.readFile full_path, Meteor.bindEnvironment(((err, data) ->
        if err
          console.log(err)
          return

        newFile = new FS.File();
        newFile._id = _rev;
        newFile.metadata = {owner:created_by, space:space, instance:ins_id, approve: approve};
        newFile.attachData data, {type: mime_type}, (err) ->
          newFile.name(filename)
          collection.insert newFile, (err, fileObj) ->
            if err
              console.log(err)
            else
              console.log(fileObj._id)
              # fileObj.on("stored", () ->
              #   console.log("onStored")
              # )
        ), ->
          console.log("Meteor.bindEnvironment failed")
        )

    fs.stat(new_path, Meteor.bindEnvironment(((err, stat) ->
        if stat && stat.isFile()
          readFile new_path
        ), ->
          console.log("Meteor.bindEnvironment failed")
        )
    )

    fs.stat(old_path, Meteor.bindEnvironment(((err, stat) ->
        if stat && stat.isFile()
          readFile old_path
        ), ->
          console.log("Meteor.bindEnvironment failed")
        )
    )

  console.log(db.instances.find({"attachments.current": {$ne: null}}).count())
  b = new Date()

  db.instances.find({"attachments.current": {$ne: null}}).forEach (ins) ->
    attachs = ins.attachments
    space = ins.space
    ins_id = ins._id
    attachs.forEach (att) ->
      deal_with_version root_path, space, ins_id, att.current, att.filename
      if att.historys
        att.historys.forEach (his) ->
          deal_with_version root_path, space, ins_id, his, att.filename

  console.log(new Date() - b)
  res.statusCode = 204
  res.end()



JsonRoutes.add "post", "/s3/remove",  (req, res, next) ->
  cfs.instances.remove({"metadata.space":"519f004e8e296a1c5f00001d"})
  res.statusCode = 204
  res.end()








