describe 'module', ->
  When -> @module = importModule('index')
  Then -> @module.create.should.not.be.undefined
  And -> @module.create.should.be.a('function')
