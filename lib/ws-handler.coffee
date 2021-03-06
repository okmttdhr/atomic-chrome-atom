temp = require 'temp'

module.exports = class WSHandler
  constructor: (@ws) ->
    @closed = false

    # chrome extensionの方でも同じようなことやっていたような
    @ws.on 'message', (message) =>
      message = JSON.parse(message)
      this[message.type](message.payload) if this[message.type]

    @ws.on 'close', () =>
      @closed = true
      @changeSubscription.dispose() if @changeSubscription
      @destroySubscription.dispose() if @changeSubscription

  register: (data) ->
    filepath = @getFile(data.title)
    atom.workspace.open(filepath).then (editor) =>
      @initEditor(editor, data)

  getFile: (title) ->
    temp.path {prefix: "#{title}-", suffix: '.txt'}

  initEditor: (editor, data) ->
    @editor = editor
    @updateText(data)
    @destroySubscription = @editor.onDidDestroy =>
      @ws.close() unless @closed
    @changeSubscription = @editor.onDidChange =>
      @sendChanges() unless @closed || @ignoreChanges
      @ignoreChanges = false

  sendChanges: ->
    message =
      type: 'updateText'
      payload:
        text: @editor.getBuffer().lines.join('\n')

    # 送信処理
    @ws.send JSON.stringify(message)

  updateText: (data) ->
    return unless @editor && @editor.isAlive()
    @ignoreChanges = true # avoid sending received changes
    @editor.setText(data.text)
