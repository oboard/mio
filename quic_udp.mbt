///|
#cfg(target="native")
#warnings("-unused_value")
async fn quic_send_client_initial(
  addr : @socket.Addr,
  destination_connection_id : Bytes,
  source_connection_id : Bytes,
  crypto_data : Bytes,
) -> QuicProtectedPacket {
  let conn = @socket.UdpClient(addr)
  defer conn.close()
  let datagram = quic_build_client_initial_datagram(
    destination_connection_id, source_connection_id, 0, crypto_data,
  )
  conn.send(datagram.packet)
  datagram
}
