# gem install rerun
# rerun 'ruby app.rb'

require 'rubygems'
require 'pubnub'
require 'sinatra'
require 'rethinkdb'
include RethinkDB::Shortcuts

pubnub = Pubnub.new(
  subscribe_key: 'demo',
  publish_key: 'demo',
)

# configure do
  enable :sessions
  # set :sessions, true
  # set :session_secret, 'secret'
# end

$connection = r.connect(
  host: "localhost",
  port: 28015, # the default RethinkDB port
  db: 'game',
)

# Root page
get '/' do
  'Welcome to RethinkDB and PubNub integration in Sinatra example!'
end

# Create a new player
post '/players' do
  name = params[:name]
  result = r.table("players").insert(name: name).run($connection) # pass in the connection to `run`
  response.set_cookie("id", {
    :value => result["generated_keys"][0],
  })
  "Player #{name} created!"
end

# Sample response after inserting a new document
#
# {
# "deleted": 0 ,
# "errors": 0 ,
# "generated_keys": [
# "9277a750-f26c-41a4-84d7-fca82158b1ce"
# ] ,
# "inserted": 1 ,
# "replaced": 0 ,
# "skipped": 0 ,
# "unchanged": 0
# }

get '/players' do
  # "id - #{session[:id]}"
  results = r.table('players').run($connection)
  results.to_a.to_json
end

# Submitting player's score
post '/players/score' do
  id = request.cookies["id"]
  score = params[:score]

  player = r.table("players").get(id).run($connection) # get the player

  score_update = {score: score} # our update parameters

  if !player["score"] || score > player["high_score"]
    # if the player doesn't have a score yet
    # or if the score is higher than their highest score
    score_update[:high_score] = score
    # add the high-score to the query
  end

  r.table("players").get(id).update(score_update).run($connection) # .update(score: 78, high_score: 78)
  {success:200}.to_json
end

# Query for leaderboard
$leaderboard = r.table("players").order_by(r.desc("high_score")).limit(5)

get '/leaderboard' do
  leaders = $leaderboard.run($connection)
  leaders.to_a.to_json
end
