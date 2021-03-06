#TODO delete, no longer being referenced
{Model} = require 'spine'
$ = require 'jqueryify'
Api = require 'zooniverse/lib/api'
seasons = require '../lib/seasons'

class Subject extends Model
  @configure 'Subject', 'zooniverseId', 'workflowId', 'location', 'coords', 'metadata'

  @queueLength: 3
  @current: null

  @next: (callback) =>
    @current.destroy() if @current?
    count = @count()

    # Prepare one "current" and fill the rest of the queue.
    toFetch = (@queueLength - count) + 1
    fetcher = @fetch toFetch unless toFetch < 1

    if count is 0
      nexter = fetcher.pipe =>
        first = @first()
        first?.destroy() if first?.metadata.empty

        if @count() is 0
          @trigger 'no-subjects'
        else
          @first().select()
    else
      nexter = new $.Deferred
      nexter.done =>
        @first().select()

      nexter.resolve()

    nexter.then callback

    nexter

  @fetch: (count) =>
    fetcher = new $.Deferred

    # Grab subjects randomly.
    getter = Api.get("/projects/serengeti/groups/subjects?limit=#{count}").deferred

    getter.done (rawSubjects) =>
      fetcher.resolve (@fromJSON rawSubject for rawSubject in rawSubjects)

    getter.fail =>
      fetcher.resolve []

    fetcher.promise() # Resolves with all fetched subjects

  @fromJSON: (raw) =>
    subject = @create
      id: raw.id
      zooniverseId: raw.zooniverse_id
      workflowId: raw.workflow_ids[0]
      location: raw.location
      coords: raw.coords
      metadata: raw.metadata

    # Preload images.
    (new Image).src = src for src in subject.location.standard

    subject

  select: ->
    @constructor.current = @
    @trigger 'select'

  satelliteImage: (width = 640, height = 480, zoom = 10, type = 'hybrid') ->
    # TODO: Fix lat/lng!
    coords = ['Serengeti', 'Tanzania']

    """
      //maps.googleapis.com/maps/api/staticmap
      ?center=#{coords.join ','}
      &zoom=#{zoom}
      &size=#{width}x#{height}
      &maptype=#{type}
      &markers=size:tiny|#{coords.join ','}
      &sensor=false
    """.replace '\n', '', 'g'

  talkHref: ->
    "http://talk.snapshotserengeti.org/#/subjects/#{@zooniverseId}"

  facebookHref: ->
    title = 'Snapshot Serengeti'
    summary = 'I just classified this image on Snapshot Serengeti!'
    image = $("<a href='#{@location.standard[0]}'></a>").get(0).href
    """
      https://www.facebook.com/sharer/sharer.php
      ?s=100
      &p[url]=#{encodeURIComponent @talkHref()}
      &p[title]=#{encodeURIComponent title}
      &p[summary]=#{encodeURIComponent summary}
      &p[images][0]=#{image}
    """.replace '\n', '', 'g'

  twitterHref: ->
    message = "Classifying animals in the Serengeti! #{@talkHref()} via @snapserengeti"
    "http://twitter.com/home?status=#{encodeURIComponent message}"

  pinterestHref: ->
    image = $("<a href='#{@location.standard[0]}'></a>").get(0).href
    summary = 'I just classified this image on Snapshot Serengeti!'
    """
      http://pinterest.com/pin/create/button/
      ?url=#{encodeURIComponent @talkHref()}
      &media=#{encodeURIComponent image}
      &description=#{encodeURIComponent summary}
    """.replace '\n', '', 'g'

module.exports = Subject
