VERBOSE = true
DEFAULT_REGION = "us-east-1"
DEFAULT_KEYPAIR = "default"

cluster1_user_data = { :queue_host => "queue1.example.net", :queue_port => 11300  }.to_json
cluster2_user_data = { :queue_host => "queue2.example.net", :queue_port => 11300  }.to_json

INSTANCE_TYPES = {
  :cluster1 => {
    :web      => {  :ami => "ami-2d4aa444",
                    :size => "m1.small",
                    :type => :spot,
                    :groups => ["Web Server", "Trusted IPs"],
                    :user_data => cluster1_user_data
                 },

    :db       => {  :ami => "ami-ccf615a5",
                    :size => "c1.medium",
                    :type => :ondemand,
                    :groups => ["DB Server", "Trusted IPs"],
                    :user_data => cluster1_user_data
                 }
  },

  :cluster2 => {
    :web      => {  :ami => "ami-2d4aa444",
                    :size => "c1.medium",
                    :type => :ondemand,
                    :groups => ["Web Server", "Trusted IPs"],
                    :user_data => cluster2_user_data
                 },

    :db       => {  :ami => "ami-ccf615a5",
                    :size => "c1.medium",
                    :type => :ondemand,
                    :groups => ["DB Server", "Trusted IPs"],
                    :user_data => cluster2_user_data
                 }
  }
}
