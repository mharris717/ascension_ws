require 'ascension'
require 'sinatra'

require 'json'

def playing_on_command_line?
  false
end

#ENV["MONGOHQ_URL"] = "mongodb://heroku:99edd370d94f3e79f26d65547982ad09@alex.mongohq.com:10051/app14554751"

def get_connection
  return @db_connection if @db_connection
  db = URI.parse(ENV['MONGOHQ_URL'])
  db_name = db.path.gsub(/^\//, '')
  @db_connection = Mongo::Connection.new(db.host, db.port).db(db_name)
  @db_connection.authenticate(db.user, db.password) unless (db.user.nil? || db.user.nil?)
  @db_connection
end


def db
  get_connection
  #@db ||= Mongo::Connection.new.db("ascension-web")
end

#Choices.setup_chooser!

helpers do
  def id_hash
    {:_id => BSON::ObjectId(params[:id])}
  end
  def set_origin
    response['Access-Control-Allow-Origin'] = 'http://localhost:5200'
  end
  def game
    set_origin
    @game ||= Game.collection.find_one_object(id_hash)
  end
end

get "/" do
  File.read "public/index.html"
end

get "/reset" do
  Game.reset!
  game.to_json
end

class File
  def self.pp(file,obj)
    require 'pp'

    File.open(file,"w") do |f|
      PP.pp(obj,f)
    end
  end
end

get "/games" do
  set_origin
  Game.collection.find_objects.to_a.to_json
end

get "/games/:id" do
  #File.pp "game.json",game.as_json

  game.to_json
end

get "/games/:id/play_card/:card" do
  set_origin
  side = game.turn_manager.current_side
  if params[:card] == "All"
    side.hand.each { |card| side.play(card) }
  else
    card = side.hand.find { |x| x.name == params[:card] }
    raise "no card #{params[:card]}" unless card
    side.play(card)
  end
  game.mongo.save!
  game.to_json
end

get "/games/:id/acquire_card/:card" do
  set_origin
  side = game.turn_manager.current_side
  card = game.center_wc.find { |x| x.name == params[:card] }
  raise "no card #{params[:card]}" unless card
  side.engage(card)
  game.mongo.save!
  game.to_json
end

get "/games/:id/advance" do
  set_origin
  game.turn_manager.advance!
  game.mongo.save!
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
  side.hand << card
  game.mongo.save!
  game.to_json

end

get "/games/:id/invoke_ability/:card" do
  set_origin

  side = game.turn_manager.current_side
  card = side.constructs.find { |x| x.card_id.to_i == params[:card].to_i }
  card.invoke_abilities(side)

  game.mongo.save!
  game.to_json

end