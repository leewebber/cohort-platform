# LOCAL TEST ONLY: private loopback config; no network requests or hosted keys.
require 'json';require 'open3';require 'uri';require 'openssl';require 'base64'
w,container,out=ARGV
raise 'Task-owned disposable fixture required' unless w.include?('sprint12_gate.s12g') && container.start_with?('supabase_db_s12g')
o,e,s=Open3.capture3('supabase','status','-o','json','--workdir',w);raise 'Local status unavailable' unless s.success?
d=JSON.parse(o);uri=URI(d.fetch('API_URL'));raise 'Loopback only' unless uri.scheme=='http'&&uri.host=='127.0.0.1'
def b(v);Base64.urlsafe_encode64(v,padding:false);end
caps={}
%w[cohort_publication_approval_writer cohort_publication_event_delivery cohort_exercise_version_publisher].each do |role|
 payload=b(JSON.generate({'role'=>role,'aud'=>'authenticated','exp'=>Time.now.to_i+3600}));head=b('{"alg":"HS256","typ":"JWT"}');data=head+'.'+payload
 caps[role]=data+'.'+b(OpenSSL::HMAC.digest('sha256',d.fetch('JWT_SECRET'),data))
 _,_,s=Open3.capture3('docker','exec','-i',container,'psql','-X','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1',stdin_data:"GRANT #{role} TO authenticator WITH INHERIT FALSE,SET TRUE;");raise 'Fixture grant failed' unless s.success?
end
File.write(out,JSON.generate({'api'=>d['API_URL'],'anon'=>d['ANON_KEY'],'service'=>d['SERVICE_ROLE_KEY'],'caps'=>caps,'container'=>container}),perm:0600)
puts 'LOCAL_ONLY_CONFIG_READY (no credential values logged)'
