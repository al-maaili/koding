kd                = require 'kd'
_                 = require 'lodash'
KDObject          = kd.Object
KDSplitView       = kd.SplitView
KDSplitViewPanel  = kd.SplitViewPanel
KDTabPaneView     = kd.TabPaneView
IDEView           = require '../views/tabview/ideview'


## This class creates a layout map for remembering the tab layout.
## You can see `/client/ide/docs/idelayoutmanager.markdown` for more information
## about this.
module.exports = class IDELayoutManager extends KDObject


  ###*
   * Create the layout map.
   *
   * @return {Array} @layout
  ###
  createLayoutData: ->

    @layout       = [] # Reset and create an array.

    workspaceView = @getDelegate().workspace.getView()
    baseSplitView = workspaceView.layout.getSplitViewByName 'BaseSplit'
    splitViews    = baseSplitView.panels.last.subViews.first.subViews.first

    if splitViews instanceof IDEView
      @createParentSplitViews splitViews
    else

      for panel in splitViews.panels when panel
        @createParentSplitViews panel

    return @layout


  ###*
   * Create first split panels.
   *
   * @param {KDSplitViewPanel} parent
  ###
  createParentSplitViews: (parent) ->

    @layout.push
      type      : 'split',
      direction : if parent.vertical is true then 'vertical' else 'horizontal'
      views     : @getSubLevels parent


  ###*
   * Seach in each dom structure.
   *
   * @param {KDSplitViewPanel} splitViewPanel
  ###
  getSubLevels: (splitViewPanel) ->

    subViews = []

    ###*
     * Create a split view object item.
     *
     * @param {string} direction
     * @param {boolean} isFirst
     * @param {Object} parentView
    ###
    createSplitView = (panel, isFirst = no, parentView) ->

      item =
        type      : 'split'
        direction : if panel.vertical then 'vertical' else 'horizontal',
        isFirst   : isFirst,
        views     : []

      if parentView
      then parentView.views.push item
      else subViews.push item

      getSubLevel panel


    ###*
     * Get/find last split object in data structure.
     *
     * <Recursive>
     * @param {Object} items
    ###
    findLastSplitView = (items = subViews) ->

      return  if _.isEmpty items
      return  if items.last.context

      lastViews = items.last.views

      if lastViews.length is 0 or (lastViews.length > 0 and lastViews.last.context)
        return items.last
      else
        findLastSplitView lastViews


    ###*
     * Search in views and create sub levels.
     *
     * <Recursive>
     * @param {(KDSplitViewPanel|KDSplitView|IDEView|KDTabPaneView|IDEApplicationTabView)} target
     * @param {KDSplitViewPanel} nextSplitViewPanel
     * @return {Array} subViews
    ###
    getSubLevel = (target) ->

      if target instanceof KDSplitViewPanel
        getSubLevel target.getSubViews().first

      else if target instanceof KDSplitView

        { panels } = target

        if panels.length is 2
          splitView = findLastSplitView()

          createSplitView panels.first, yes,  splitView
          createSplitView panels.last,  no,   splitView
        else
          getSubLevel panels.first

      else if target instanceof IDEView

        for pane in target.tabView.panes
          getSubLevel pane

      else if target instanceof KDTabPaneView
        return  unless target.view.serialize

        pane = context : target.view.serialize()
        last = findLastSplitView()

        if last
        then last.views.push pane
        else subViews.push pane


    getSubLevel splitViewPanel

    return subViews


  ###*
   * Resurrect saved snapshot from server.
   *
   * @param {Array} snapshot
  ###
  resurrectSnapshot: (snapshot) ->

    # if has the fake view
    @delegate.mergeSplitView()  if @delegate.ideViews.length > 1

    @delegate.splitTabView snapshot[1].direction  if snapshot[1]

    for key, value of snapshot
      tabView = @delegate.ideViews[key]?.tabView
      @resurrectPanes_ value.views, tabView

    @delegate.isLocalSnapshotRestored = yes


  resurrectPanes_: (items, tabView) ->

    for key, value of items

      @delegate.setActiveTabView tabView

      if value.type is 'split'

        if value.isFirst isnt yes
          @delegate.splitTabView value.direction
          tabView = @delegate.ideViews.last.tabView

        if value.views.length
          do (value, tabView) =>
            kd.utils.defer => @resurrectPanes_ value.views, tabView

      else
        # Don't use `active tab view` logic for new pane creation.
        # Because `The Editors` (saved editors) are loading async.
        value.targetTabView = tabView  if value.context.paneType is 'editor'
        @delegate.createPaneFromChange value, yes
