(function() {
  var getRootModel, wsUrl;

  window.App = Em.Application.create();

  wsUrl = "http://localhost:5100";

  getRootModel = function(obj) {
    while (obj && obj.get && obj.get("model")) {
      obj = obj.get("model");
    }
    if (obj && obj.get && obj.get("isGameController")) {
      stillController();
    }
    return obj;
  };

  App.Router.map(function() {
    return this.resource("games", function() {
      return this.resource("game", {
        path: ":game_id"
      }, function() {
        return this.resource("side", {
          path: ":side_id"
        });
      });
    });
  });

  App.Game = Em.Object.extend({
    setFromRaw: function(resp) {
      var k, v, _results;
      resp = getRootModel(resp);
      App.Game.fixRawId(resp);
      _results = [];
      for (k in resp) {
        v = resp[k];
        _results.push(this.set(k, v));
      }
      return _results;
    },
    reload: function() {
      var _this = this;
      console.debug("Reloading");
      return App.Game.findOne(this.get("id"), true).then(function(resp) {
        return _this.setFromRaw(resp);
      });
    }
  });

  App.Game.reopenClass({
    fixRawId: function(g) {
      var id;
      id = g["_id"] || g["mongo_id"];
      if (!id) {
        console.debug(g);
      }
      return g["id"] = id["$oid"];
    },
    fromRaw: function(resp) {
      this.fixRawId(resp);
      return App.Game.create(resp);
    },
    find: function() {
      var res,
        _this = this;
      res = Em.ArrayController.create({
        model: []
      });
      return $.getJSON("" + wsUrl + "/games").then(function(resp) {
        var g, _i, _len, _results;
        _results = [];
        for (_i = 0, _len = resp.length; _i < _len; _i++) {
          g = resp[_i];
          _results.push(res.pushObject(_this.fromRaw(g)));
        }
        return _results;
      });
    },
    findOne: function(id, raw) {
      var res,
        _this = this;
      if (raw == null) {
        raw = false;
      }
      res = Em.ObjectController.create({
        model: null
      });
      return $.getJSON("" + wsUrl + "/games/" + id).then(function(resp) {
        var g;
        _this.fixRawId(resp);
        if (raw) {
          return res.set("model", resp);
        } else {
          g = _this.fromRaw(resp);
          return res.set("model", g);
        }
      });
    }
  });

  App.GamesRoute = Em.Route.extend({
    model: function() {
      return App.Game.find();
    }
  });

  App.GameRoute = Em.Route.extend({
    model: function(params) {
      return App.Game.findOne(params.game_id);
    }
  });

  App.SideRoute = Em.Route.extend({
    model: function(params) {
      var game, res, sideNum;
      sideNum = params.side_id;
      game = this.controllerFor("game");
      res = App.DynamicSide.create({
        rawSideNum: sideNum,
        gameController: game
      });
      setTimeout(function() {
        return setInterval(function() {
          return getRootModel(game).reload();
        }, 2000);
      }, 1500);
      return res;
    }
  });

  App.DynamicSide = Em.ObjectController.extend({
    game: (function() {
      return this.get("gameController.model");
    }).property("gameController.model"),
    sideNum: (function() {
      var raw;
      raw = this.get("rawSideNum");
      if (raw === 'current') {
        return parseInt(this.get("game.current_side_index")) + 1;
      } else {
        return parseInt(raw);
      }
    }).property("rawSideNum", "game.current_side_index"),
    content: (function() {
      var game, sides;
      game = this.get("game");
      if (!game) {
        return void 0;
      }
      sides = game.get("sides");
      return sides[this.get("sideNum") - 1];
    }).property("game", "sideNum", "game.sides.@each")
  });

  App.GamesController = Em.ArrayController.extend({
    resetGame: function() {
      return $.getJSON("" + wsUrl + "/reset");
    },
    showGames: (function() {
      return true;
    }).property()
  });

  App.GameController = Em.ObjectController.extend({
    centerCards: (function() {
      var engageableNames;
      engageableNames = _.pluck(this.get("engageable_cards"), "name");
      return _.map(this.get("center.cards"), function(card) {
        card.engageable = _.include(engageableNames, card.name);
        return card;
      });
    }).property("engageable_cards.@each", "center.cards"),
    constantCards: (function() {
      var engageableNames;
      engageableNames = _.pluck(this.get("engageable_cards"), "name");
      return _.map(this.get("constant_cards"), function(card) {
        card.engageable = _.include(engageableNames, card.name);
        return card;
      });
    }).property("engageable_cards.@each", "constant_cards"),
    acquireCard: function(card) {
      var game, id;
      game = this.get("model");
      id = game.get("id");
      return $.getJSON("" + wsUrl + "/games/" + id + "/acquire_card/" + card.name).then(function(resp) {
        return getRootModel(game).setFromRaw(resp);
      });
    },
    setFromRaw: function(raw) {
      return triedToSetFromRawOnController();
    },
    isGameController: (function() {
      return true;
    }).property(),
    addCard: function() {
      var card, game, id, sideNum,
        _this = this;
      game = this.get("model");
      id = game.get("id");
      card = this.get("cardToAdd");
      sideNum = 1;
      return $.getJSON("" + wsUrl + "/games/" + id + "/" + sideNum + "/add_card/" + card).then(function(resp) {
        getRootModel(game).setFromRaw(resp);
        return _this.set("cardToAdd", "");
      });
    }
  });

  App.SideController = Em.ObjectController.extend({
    isCurrent: (function() {
      var currentSideNum, game, res;
      game = this.get("game");
      currentSideNum = game.get("current_side_index") + 1;
      res = currentSideNum === this.get("sideNum");
      return res;
    }).property("game.current_side_index", "sideNum"),
    hasChoice: (function() {
      return this.get("choices") && this.get("choices").length > 0 && this.get("isCurrent");
    }).property("choices.@each", "isCurrent"),
    otherSide: (function() {
      var other;
      other = 3 - this.get("sideNum");
      return App.DynamicSide.create({
        rawSideNum: other,
        gameController: this.get("gameController")
      });
    }).property("model", "game.sides.@each", "sideNum", "gameController", "game.sides.@each.pool.runes", "game.last_update_dt"),
    playCard: function(card) {
      var game, id;
      console.debug("playing " + card.name);
      game = this.get("game");
      id = game.get("id");
      return $.getJSON("" + wsUrl + "/games/" + id + "/play_card/" + card.name).then(function(resp) {
        return getRootModel(game).setFromRaw(resp);
      });
    },
    endTurn: function() {
      var game, id;
      game = this.get("game");
      id = game.get("id");
      return $.getJSON("" + wsUrl + "/games/" + id + "/advance").then(function(resp) {
        return getRootModel(game).setFromRaw(resp);
      });
    },
    showPlayAll: (function() {
      return this.get("isCurrent") && this.get("hand.cards").length > 1;
    }).property("isCurrent", "hand.cards.@each"),
    playAll: function() {
      return this.playCard({
        name: "All"
      });
    },
    engageableCardNames: (function() {
      return _.map(this.engageable_cards, function(c) {
        return c.name;
      });
    }).property("engageable_cards", "pool.runes", "pool.power"),
    chooseOption: function(choice, card) {
      var game, id;
      if (!card) {
        card = {
          card_id: "null"
        };
      }
      game = this.get("game");
      id = game.get("id");
      return $.getJSON("" + wsUrl + "/games/" + id + "/choose_option/" + choice.choice_id + "/" + card.card_id).then(function(resp) {
        return getRootModel(game).setFromRaw(resp);
      });
    },
    invokeAbility: function(card) {
      var game, id;
      game = this.get("game");
      id = game.get("id");
      return $.getJSON("" + wsUrl + "/games/" + id + "/invoke_ability/" + card.card_id).then(function(resp) {
        return getRootModel(game).setFromRaw(resp);
      });
    }
  });

}).call(this);
