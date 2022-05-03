{ createMiddleware } = importModule('LoggingMiddleware')
{ ctx } = require('@code-dungeon/context-continuation')

describe 'LoggingMiddleware', ->
  Given ->
    @firstWriteData = Buffer.from('response')
    @secondWriteData = Buffer.from('.')
    @entryLogger = { info: spy(), error: spy() }
    @exitLogger = { info: spy(), error: spy() }
    @execute = createMiddleware(@entryLogger, @exitLogger)
    @end = spy()
    @write = spy()
    @req = {
      get: spy()
    }
    @res = {
      write: @write
      end: @end
    }
    @next = spy()

  When (done) ->
    @execute(@req, @res, @next)
    @res.write(@firstWriteData)
    @res.write(@secondWriteData)
    @res.write(null)
    @res.end()
    @res.end() # just to make sure the exit isn't called twice

  describe 'no correlation-id', ->
    Then -> @next.should.have.been.calledOnce
    And -> @req.get.should.have.been.calledWith('correlation-id')
    And -> expect(ctx.cid).to.not.be.undefined
    And -> ctx.cid.should.be.a('string')

  describe 'with correlation-id', ->
    Given ->
      @req.get = stub()
      @req.get.withArgs('correlation-id').returns('correlation-id')
      @next = => @correlationId = ctx.cid
    Then -> @correlationId.should.eql('correlation-id')

  describe 'without http request body data', ->
    Given ->
      @req.get = stub()
      @req.method = 'GET'
      @req.route = {path:'src/app'}
      @res.statusCode = 200
      @next = => @http = ctx.http
    Then -> @http.path.should.equal('src/app')
    And -> @http.request.should.eql(@req)
    And -> @http.response.should.eql(@res)
    And -> @http.status.should.equal(200)
    And -> expect(@http.requestBody).to.be.undefined
    And -> @http.responseBody.should.equal('response.')
    And -> @http.duration.should.be.a('number')
    And -> @http.ttfb.should.be.a('number')

  describe 'with http request body data', ->
    Given ->
      @req.get = stub()
      @req.method = 'POST'
      @req.body = 'body'
      @req.route = {path:'src/app'}
      @res.statusCode = 200
      @next = => @http = ctx.http
    Then -> @http.path.should.equal('src/app')
    And -> @http.request.should.eql(@req)
    And -> @http.response.should.eql(@res)
    And -> @http.status.should.equal(200)
    And -> @http.requestBody.should.equal('body')
    And -> @http.responseBody.should.equal('response.')
    And -> @http.duration.should.be.a('number')
    And -> @http.ttfb.should.be.a('number')

  describe 'with no response data', ->
    Given ->
      @req.get = stub()
      @res.statusCode = 204
      @firstWriteData = null
      @secondWriteData = null
      @next = => @http = ctx.http
    Then -> @http.status.should.equal(204)
    And -> expect(@http.responseBody).to.be.undefined
    And -> @http.duration.should.be.a('number')
    And -> @http.ttfb.should.be.a('number')

  # res methods are patched, so the test for them should still be they were executed
  describe 'end', ->
    When -> @res.statusCode = 200
    Then -> @end.should.not.equal(@res.end)
    And -> @end.should.have.been.calledWith()

  describe 'calls loggers', ->
    describe 'entry and exit logger defined', ->
      Given -> @execute = createMiddleware(@entryLogger, @exitLogger)

      describe 'success', ->
        Given -> @res.statusCode = 200
        Then -> @entryLogger.info.should.have.been.calledOnce
        And -> @entryLogger.info.should.have.been.calledWith({state:'enter'})
        And -> @exitLogger.info.should.have.been.calledOnce
        And -> @exitLogger.info.should.have.been.calledWith({state:'exit'})
        And -> @exitLogger.info.should.have.been.calledAfter(@entryLogger.info)

      describe 'failure', ->
        Given -> @res.statusCode = 500
        Then -> @entryLogger.info.should.have.been.calledOnce
        And -> @entryLogger.info.should.have.been.calledWith({state:'enter'})
        And -> @exitLogger.error.should.have.been.calledOnce
        And -> @exitLogger.error.should.have.been.calledWith({state:'exit'})
        And -> @exitLogger.error.should.have.been.calledAfter(@entryLogger.info)

    describe 'only entry logger is defined', ->
      Given -> @execute = createMiddleware(@entryLogger)

      describe 'success', ->
        Given -> @res.statusCode = 200
        Then -> @entryLogger.info.should.have.been.calledTwice
        And -> @entryLogger.info.firstCall.args.should.eql([{state: 'enter'}])
        And -> @entryLogger.info.secondCall.args.should.eql([{state: 'exit'}])

      describe 'failure', ->
        Given -> @res.statusCode = 500
        Then -> @entryLogger.info.should.have.been.calledOnce
        And -> @entryLogger.info.should.have.been.calledWith({state:'enter'})
        And -> @entryLogger.error.should.have.been.calledOnce
        And -> @entryLogger.error.should.have.been.calledWith({state:'exit'})
        And -> @entryLogger.error.should.have.been.calledAfter(@entryLogger.info)
  # describe 'logExit', ->
  #   describe 'write', ->
  #     When ->
  #       @buffer = Buffer.from('test')
  #       @res.write(@buffer)
  #       @res.write(null)
  #       @res.end(@buffer)
  #     Then -> @write.should.have.been.called

  #   describe 'write not defined', ->
  #     Given -> @res.write = undefined
  #     Then -> @write.should.not.have.been.called

  #   describe 'multiple end status', ->
  #     When ->
  #       @res.statusCode = 200
  #       @res.end({})
  #       @res.end({})
  #       @res.end({})
  #     #no real way to test for a single end until we do dependency injection
  #     Then -> @end.should.not.equal(@res.end)
  #     And -> @end.should.have.been.calledWith({})
