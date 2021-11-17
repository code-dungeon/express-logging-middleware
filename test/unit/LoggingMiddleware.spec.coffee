{create} = importModule('LoggingMiddleware')
{ctx} = require('@code-dungeon/context-continuation')

describe 'LoggingMiddleware', ->
  Given ->
    @entryLogger = { info: spy() }
    @exitLogger = { info: spy(), error: spy() }
    @execute = create(@entryLogger, @exitLogger)
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

  When -> @execute(@req, @res, @next)

  describe 'no correlation-id', ->
    Then -> @next.should.have.been.calledOnce
    And -> @req.get.should.have.been.calledWith('correlation-id')

  describe 'with correlation-id', ->
    Given ->
      @req.get = stub()
      @req.get.withArgs('correlation-id').returns('correlation-id')
      @next = => @correlationId = ctx.cid
    Then -> @correlationId.should.eql('correlation-id')

  describe 'with no http data', ->
    Then -> @next.should.have.been.calledOnce

  describe 'with http data', ->
    Given ->
      @req.get = stub()
      @req.method = 'GET'
      @req.route = {path:'src/app'}
      @res.statusCode = 200
      @next = => @http = ctx.http
    Then -> @http.path.should.equal('src/app')
    And -> @http.request.should.equal(@req)
    And -> @http.response.should.equal(@res)

  describe 'logExit', ->
    describe 'write', ->
      When ->
        @buffer = Buffer.from('test')
        @res.write(@buffer)
        @res.write(null)
        @res.end(@buffer)
      Then -> @write.should.have.been.called
    
    describe 'write not defined', ->
      Given -> @res.write = undefined
      Then -> @write.should.not.have.been.called
        
    describe 'multiple end status', ->
      When ->
        @res.statusCode = 200
        @res.end({})
        @res.end({})
        @res.end({})
      #no real way to test for a single end until we do dependency injection
      Then -> @end.should.not.equal(@res.end)
      And -> @end.should.have.been.calledWith({})

    #res methods are patched, so the test for them should still be they were executed
    describe 'end', ->
      When ->
        @res.statusCode = 500
        @res.end({})
      Then -> @end.should.not.equal(@res.end)
      And -> @end.should.have.been.calledWith({})

    describe 'route', ->
      Given ->
        @req.route = {path: 'some path'}
        @execute = create(@entryLogger, @exitLogger)
      When ->
        @res.statusCode = 500
        @res.end({})
      Then -> @end.should.not.equal(@res.end)
      And -> @end.should.have.been.calledWith({})
