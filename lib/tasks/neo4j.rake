namespace :neo4j do
  desc "Verify the connection to Neo4j Aura"
  task verify: :environment do
    rows = Neo4j::Client.new.query("RETURN 1 AS value")

    if rows == [ { "value" => 1 } ]
      puts "Neo4j Aura connection verified."
    else
      abort "Neo4j Aura returned an unexpected verification result."
    end
  rescue Neo4j::Client::Error => error
    abort "Neo4j Aura verification failed: #{error.message}"
  end
end
