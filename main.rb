require 'ascension'
require 'sinatra'

require 'json'

def setupPusher
  require 'pusher'
  Pusher.app_id = '41907'
  Pusher.key = '28c727618e7719053306'
  Pusher.secret = '2aab6122065bfed2222d'
end
setupPusher

def playing_on_command_line?
  false
end

ENV["MONGOHQ_URL"] = "mongodb://heroku:99edd370d94f3e79f26d65547982ad09@alex.mongohq.com:10051/app14554751"

def get_connection
  return @db_connection if @db_connection
  db = URI.parse(ENV['MONGOHQ_URL'])
  db_name = db.path.gsub(/^\//, '')
  @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
  @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  @db_connection
end

Ascension.db = Mongo::Connection.new.db("ascension-web")

#Choices.setup_chooser!

helpers do
  def id_hash(id=nil)
    id ||= params[:id]
    {:_id => BSON::ObjectId(id)}
  end
  def set_origin
    response['Access-Control-Allow-Origin'] = 'http://localhost:5200'
  end
  def game_old
    set_origin
    @game ||= Game.collection.find_one_object(id_hash)
  end
  def game_hash
    @game_hash ||= {}
  end
  def get_game(id)
    game_hash[id] ||= Game.collection.find_one_object(id_hash(id))
  end
  def game
    set_origin
    get_game(params[:id])
  end

  def send_reload!(side_num=nil)
    side_num ||= game.turn_manager.current_side_index + 1
    chan = game.mongo_id.to_s
    puts "Chan #{chan}"
    Pusher[chan].trigger "reload",{:sideNum => side_num}
  end
end

get "/" do
  File.read "public/index.html"
end

get "/reset" do
  Game.reset!
  Game.collection.find_one_object.to_json
end

class File
  def self.pp(file,obj)
    require 'pp'

    File.open(file,"w") do |f|
      PP.pp(obj,f)
    end
  end
end

def tm(name)
  t = Time.now
  res = yield
  elapsed = Time.now - t
  puts "#{name} took #{elapsed}"
  res
end

get "/cards" do
  set_origin
  Ascension.load_files!
  Card.initial_card_info
end

get "/games" do
  set_origin
  a = Game.collection.find_objects.to_a
  #require 'pp'
  #pp a
  a.to_json
end

get "/games/:id" do
  #File.pp "game.json",game.as_json

  tm "game json" do
    game.to_json
  end
end

get "/side/:id" do
  game.turn_manager.current_side.to_json
end

get "/games/:id/pp" do
  Ascension.load_files!
  #File.pp "game.json",game.as_json

  res = game.as_json
  File.pp "game_pp.json",res
  str = File.read "game_pp.json"
  "<pre>#{str}</pre>"
end

get "/games/:id/play_card/:card" do
  res = nil

  tm "Entire Thing" do
    set_origin
    side = game.turn_manager.current_side
    if params[:card] == "All"
      side.hand.each { |card| side.play(card) }
    else
      card = side.hand.find { |x| x.name == params[:card] }
      raise "no card #{params[:card]}" unless card
      side.play(card)
    end

    tm "saving game" do
      game.mongo.save!
    end

    send_reload!

    
    tm "game to_json" do
      res = game.to_json
    end
  end
  
  res
end

get "/games/:id/play_trophy/:card" do
  set_origin
  side = game.turn_manager.current_side
  card = side.trophies.find { |x| x.card_id == params[:card].to_i }
  raise "no card #{params[:card]}" unless card
  side.trophies.play(card)
  game.mongo.save!
  send_reload!
  game.to_json
end

get "/games/:id/acquire_card/:card" do
  set_origin
  side = game.turn_manager.current_side
  card = game.center_wc.find { |x| x.name == params[:card] }
  raise "no card #{params[:card]}" unless card
  side.engage(card)
  game.mongo.save!
  send_reload!
  game.to_json
end

get "/games/:id/advance" do
  set_origin
  side_num = game.turn_manager.current_side_index + 1
  game.turn_manager.advance!
  game.mongo.save!
  send_reload! side_num
  game.to_json
end

get "/games/:id/choose_option/:choice_id/:card" do
  set_origin

  side = game.turn_manager.current_side
  choice = side.choices.find { |x| x.choice_id.to_s == params[:choice_id].to_s }
  card = if params[:card] == "null"
    nil
  else
    game.find_card params[:card]
  end

  choice.execute! card
  game.turn_manager.resume!
  game.mongo.save!
  send_reload!
  game.to_json
end

get "/games/:id/:side_index/add_card/:card" do
  set_origin
  puts "Adding card #{params[:card]}"
  raise "no card given" if params[:card].blank?

  side = game.turn_manager.current_side
  card = Parse.get(params[:card])
  puts card.inspect
  puts card.as_json.inspect

  if card.kind_of?(Card::Monster)
    game.center[5] = card
  else
    side.hand << card
  end
  game.mongo.save!
  send_reload!
  game.to_json

end

get "/games/:id/invoke_ability/:card" do
  set_origin

  side = game.turn_manager.current_side
  card = side.constructs.find { |x| x.card_id.to_i == params[:card].to_i }
  card.invoke_abilities(side)

  game.mongo.save!
  send_reload!
  game.to_json

end