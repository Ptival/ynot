let http_crlf = (String.make 1 (Char.chr 13)) ^ (String.make 1 (Char.chr 10))

let http_parse_test () =
  let rec read_all () =
    let x = read_line () in
    if x = ""
    then http_crlf
    else Printf.sprintf "%s%s%s" x http_crlf (read_all ())
  in
  let q = read_all () in
  let la = MlCoq.string_to_la q in
  let _ = print_string ("parsing \"" ^ q ^ "\""); flush stdout in
  match STImpl.exec (HttpTest.parse_test la) with
  | None -> print_string "failed"
  | Some y -> print_string "passed"
;;

let skt = Unix.ADDR_INET ((Unix.inet_addr_of_string "127.0.0.1"), 8081) in
let server = ref (fun () -> failwith "Must select a server") in
let options = 
    [(** Simple servers **)
     ("-udpecho", 
      Arg.Unit (fun _ -> server := fun () -> 
	let _ = STImpl.exec (EchoServer.udp skt) in ()),
      "run the udp echo server");
     ("-udpeval", 
      Arg.Unit (fun _ -> server := fun () -> 
       let _ = STImpl.exec (EvalServer.udp skt) in ()),
      "run the udp eval server");
     ("-tcpecho", 
      Arg.Unit (fun _ -> server := fun () -> 
       let _ = STImpl.exec (EchoServer.tcp skt) in ()),
      "run the tcp echo server");
     ("-tcpeval",
      Arg.Unit (fun _ -> server := fun () -> 
       let _ = STImpl.exec (EvalServer.tcp skt) in ()),
      "run the tcp eval server");
     ("-sslecho", 
      Arg.Unit (fun _ -> server := fun () -> 
       let _ = STImpl.exec (EchoServer.ssl skt) in ()),
      "run the ssl echo server");
     ("-ssleval",
      Arg.Unit (fun _ -> server := fun () -> 
       let _ = STImpl.exec (EvalServer.ssl skt) in ()),
      "run the ssl eval server");

     (** Grade Server **)
     ("-http-grade", 
      Arg.Unit (fun _ -> 
	let _ = STImpl.exec (GradebookStoreImpl.http skt) in ()),
      "run the course grade server");

     (** Simple clients **)
     ("-udpclient",
      Arg.Unit (fun _ -> 
	let local = 
	  Unix.ADDR_INET ((Unix.inet_addr_of_string "127.0.0.1"), 8082)
	in server := (fun () -> 
	  let _ = STImpl.exec (UdpClient.client local skt) in ())),
      "run the udp echo client");
     ("-tcpclient",
      Arg.Unit (fun _ -> 
	let local = 
	  Unix.ADDR_INET ((Unix.inet_addr_of_string "127.0.0.1"), 8082)
	in server := (fun () -> 
	  let _ = STImpl.exec (TcpClient.client local skt) in ())),
      "run the tcp echo client");

     (** "Test" Programs **)
     ("-parse-http",
      Arg.Unit (fun _ -> server := http_parse_test),
      "test the http parser")
   ]
in
let _ = server := fun () -> Arg.usage options "Must select a server" in
let _ = 
  Arg.parse options (fun _ -> ()) "run a server"
in (!server) ()
