require 'sinatra'
require 'sinatra/reloader'
require 'googleauth'
require 'googleauth/stores/file_token_store'
require 'googleauth/web_user_authorizer'
require 'google/apis/site_verification_v1'
require 'debug'

enable :sessions


scopes = [
  'https://www.googleapis.com/auth/siteverification',
  'https://www.googleapis.com/auth/siteverification.verify_only'
]
client_id = Google::Auth::ClientId.from_file('/path/to/credential.json')
token_store = Google::Auth::Stores::FileTokenStore.new(file: 'tokens.yaml')
authorizer = Google::Auth::WebUserAuthorizer.new(client_id, scopes, token_store, '/callback')
user_id = 'hoge'

get '/' do
  erb :index
end

get '/google_login' do
  redirect authorizer.get_authorization_url(login_hint: user_id, request: request)
end

get '/callback' do
  credentials, redirect_uri = authorizer.handle_auth_callback(user_id, request)
  SiteVerification = Google::Apis::SiteVerificationV1 # Alias the module
  service = SiteVerification::SiteVerificationService.new

  # site の構造はここを参考にした
  # https://developers.google.com/admin-sdk/reseller/v1/codelab/end-to-end#ruby_1
  #
  # verification_method の種類はこちら
  # https://developers.google.com/site-verification/v1/getting_started#tokens
  get_web_resource_token_request_object = SiteVerification::GetWebResourceTokenRequest.new(site: {
    type: 'SITE',
    identifier: 'https://ykyk1218.github.io'
  }, verification_method: 'META')
  service.authorization = credentials

  # 指定した verification_method の種類によってレスポンスが変わりそう
  get_web_resource_token_response = service.get_web_resource_token(get_web_resource_token_request_object)

  # 埋め込むMETAタグが取得できる
  get_web_resource_token_response.token

  site_verification_web_resource_resource_object = SiteVerification::SiteVerificationWebResourceResource.new(site: {
    type: 'SITE',
    identifier: 'https://ykyk1218.github.io'
  })

  # token の認証に失敗すると
  # Google::Apis::ClientError - badRequest: The necessary verification token could not be found on your site.:
  # で例外が発生
  #
  # 成功すると
  # Google::Apis::SiteVerificationV1::SiteVerificationWebResourceResource オブジェクトが返る
  service.insert_web_resource('META', site_verification_web_resource_resource_object)

  erb :complete
end
