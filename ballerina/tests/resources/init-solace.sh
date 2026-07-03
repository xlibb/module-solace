#!/bin/bash

# SEMP API configuration
SEMP_URL="http://localhost:8080/SEMP/v2/config"
MONITOR_URL="http://localhost:8080/SEMP/v2/monitor"
AUTH="admin:admin"
VPN="default"

# Wait for the broker's message VPN to become operationally "up" before provisioning and testing.
# SEMP (config plane) responds well before guaranteed messaging (message spool) is ready, so a fixed
# sleep is not enough: queue/durable/transacted tests fail intermittently if they run while the VPN
# state is still "down". Poll the monitor API for state == "up".
echo "Waiting for Solace message VPN '$VPN' to become operational..."
vpn_up=false
for i in $(seq 1 60); do
    state=$(curl -s -u "$AUTH" "$MONITOR_URL/msgVpns/$VPN?select=state" 2>/dev/null \
        | grep -o '"state"[[:space:]]*:[[:space:]]*"[^"]*"' | grep -o '[^"]*"$' | tr -d '"')
    if [ "$state" = "up" ]; then
        echo "Message VPN is up after ~$((i * 3))s"
        vpn_up=true
        break
    fi
    sleep 3
done

if [ "$vpn_up" != "true" ]; then
    echo "WARNING: Message VPN did not report 'up' within the timeout; proceeding anyway."
fi

# Settle margin after the VPN reports up. The transaction subsystem needs a little longer than plain
# guaranteed messaging to stabilize, so give it extra headroom to avoid flaky transacted tests.
sleep 10

# Function to create a queue
create_queue() {
    local queue_name=$1
    echo "Creating queue: $queue_name"

    curl -X POST "$SEMP_URL/msgVpns/$VPN/queues" \
        -u "$AUTH" \
        -H "Content-Type: application/json" \
        -d "{
            \"queueName\": \"$queue_name\",
            \"accessType\": \"exclusive\",
            \"permission\": \"delete\",
            \"ingressEnabled\": true,
            \"egressEnabled\": true,
            \"respectTtlEnabled\": true
        }" \
        2>/dev/null

    # Subscribe queue to topic with same name (for topic-to-queue mapping)
    curl -X POST "$SEMP_URL/msgVpns/$VPN/queues/$queue_name/subscriptions" \
        -u "$AUTH" \
        -H "Content-Type: application/json" \
        -d "{
            \"subscriptionTopic\": \"$queue_name\"
        }" \
        2>/dev/null
}

# Producer test queues
echo "Creating producer test queues..."
create_queue "test/producer/init/queue"
create_queue "test/producer/text/queue"
create_queue "test/producer/binary/queue"
create_queue "test/producer/properties/queue"
create_queue "test/producer/metadata/queue"
create_queue "test/producer/ttl/queue"
create_queue "test/producer/persistent/queue"
create_queue "test/producer/userdata/queue"
create_queue "test/producer/compression/queue"

# Producer transaction test queues
echo "Creating producer transaction test queues..."
create_queue "test/producer/tx/commit/queue"
create_queue "test/producer/tx/rollback/queue"
create_queue "test/producer/tx/multiple/queue"

# Consumer test queues
echo "Creating consumer test queues..."
create_queue "test/consumer/init/queue"
create_queue "test/consumer/text/queue"
create_queue "test/consumer/binary/queue"
create_queue "test/consumer/properties/queue"
create_queue "test/consumer/metadata/queue"
create_queue "test/consumer/timeout/queue"
create_queue "test/consumer/nowait/queue"
create_queue "test/consumer/selector/queue"
create_queue "test/consumer/multiple/queue"
create_queue "test/consumer/flow/queue"

# Consumer transaction test queues
echo "Creating consumer transaction test queues..."
create_queue "test/consumer/tx/commit/queue"
create_queue "test/consumer/tx/rollback/queue"
create_queue "test/consumer/tx/multiple/queue"
create_queue "test/consumer/tx/mixed/queue"
create_queue "test/consumer/tx/coordinated/queue"

# Client ACK test queues
echo "Creating client ACK test queues..."
create_queue "test/consumer/ack/single/queue"
create_queue "test/consumer/ack/multiple/queue"
create_queue "test/consumer/nack/requeue/queue"
create_queue "test/consumer/nack/reject/queue"
create_queue "test/consumer/ack/redelivery/queue"

# Listener test queues
echo "Creating listener test queues..."
create_queue "test/listener/autoack/queue"
create_queue "test/listener/clientack/queue"
create_queue "test/listener/nack/queue"
create_queue "test/listener/tx/commit/queue"
create_queue "test/listener/tx/rollback/queue"

# Error test queues
echo "Creating error test queues..."
create_queue "test/error/empty/payload/queue"
create_queue "test/error/large/payload/queue"
create_queue "test/error/special/chars/queue"

# REST consumer test queues
echo "Creating REST consumer test queues..."
create_queue "jsonQueue"
create_queue "textQueue"
create_queue "xmlQueue"
create_queue "binaryQueue"
create_queue "invalidJsonQueue"
create_queue "emptyRestQueue"

echo "Queue creation completed!"
echo "Solace broker is ready for testing."
