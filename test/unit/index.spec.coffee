describe 'module', ->
  When -> @module = importModule('index')
  Then -> expect(@module.create).to.not.be.undefined
  And -> @module.create.should.be.a('function')
