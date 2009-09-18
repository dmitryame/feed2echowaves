require 'rubygems'
require 'oauth'
require 'feedzirra'
require "rexml/document"

##
# Please, supply all the configuration parameters below
#
# FEED:             the feed you want to publish to EchoWaves, can be any atom or rss feed
#
# METADATA_FILE:    in this file the program keeps the information of the already published feed entries
#
# TOKENS_FILE:      after the user allows the program to access EchoWaves through OAuth,
#                   the program keep the tokens in this file
# 
# ECHOWAVES_URL:    the url of your echowaves installation
#
# CREATE_NEW_CONVO: make it true if you want to create a new convo for every post
#
# CONVO_ID:         the id of the convo where the feed will be published
#
# CONSUMER_KEY:     register your app in ECHOWAVES_URL/oauth_clients to get your consumer key
#
# CONSUMER_SECRET:  register your app in ECHOWAVES_URL/oauth_clients to get your secret key
#
# Also search for the 'text' variable near the end of this file and customize it for the info you want to publish
#
FEED = 
METADATA_FILE = 
TOKENS_FILE = 
ECHOWAVES_URL = 
CREATE_NEW_CONVO = true
CONVO_ID =
CONSUMER_KEY = 
CONSUMER_SECRET = 
BEFORE_TXT = ''
AFTER_TXT = ''
# end of the user configuration


metadata = if File.exists?(METADATA_FILE)
  Marshal.load( File.read(METADATA_FILE) )
else
  Hash.new( Time.at(0) )
end

tokens = if File.exists?(TOKENS_FILE)
  Marshal.load( File.read(TOKENS_FILE) )
else
  Hash.new
end

consumer = OAuth::Consumer.new(
  CONSUMER_KEY, 
  CONSUMER_SECRET, 
  {:site => ECHOWAVES_URL}
)

def get_access_token(consumer, tokens)
  if tokens['atoken'] && tokens['asecret']
    access_token = OAuth::AccessToken.new(consumer, tokens['atoken'], tokens['asecret'])
    return access_token

  elsif tokens['rtoken'] && tokens['rsecret']
    request_token = OAuth::RequestToken.new(consumer, tokens['rtoken'], tokens['rsecret'])
    access_token = request_token.get_access_token
    tokens['atoken'] = access_token.token
    tokens['asecret'] = access_token.secret
    tokens.delete('rtoken')
    tokens.delete('rsecret')
    File.open( TOKENS_FILE, 'w' ) do|f|
      f.write Marshal.dump(tokens)
    end
    return access_token
    
  else
    request_token = consumer.get_request_token
    tokens['rtoken'] = request_token.token
    tokens['rsecret'] = request_token.secret
    File.open( TOKENS_FILE, 'w' ) do|f|
      f.write Marshal.dump(tokens)
    end
    # authorize in the browser
    %x(open #{request_token.authorize_url})
    exit
  end
end


access_token = get_access_token(consumer, tokens)

feed = Feedzirra::Feed.fetch_and_parse( FEED )

feed.entries.reverse.each_with_index do|i,idx|
  if i.published > metadata[FEED]
    
    ##
    # customize the info you want to publish here
    #
    text = "#{BEFORE_TXT}\n#{i.title}\n#{i.url}\n#{AFTER_TXT}"[0, 100]


    if(CREATE_NEW_CONVO == true) 
      #create a convo
      response = access_token.post("#{ECHOWAVES_URL}/conversations.xml", "conversation[name]=#{text}&conversation[read_only]=0&conversation[private]=0&conversation[something]=")            

      xmldoc = REXML::Document.new response.body

      CONVO_ID = xmldoc.root.elements["id"].text
    end

    access_token.post("#{ECHOWAVES_URL}/conversations/#{CONVO_ID}/messages.xml", "message[message]=#{text}")
    
    
    
    metadata[FEED] = i.published
    File.open( METADATA_FILE, 'w' ) do|f|
      f.write Marshal.dump(metadata)
    end

    sleep 5
  end
end