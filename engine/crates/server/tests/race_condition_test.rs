use std::time::Duration;
use tokio_tungstenite::tungstenite::Message;

// Esse teste tenta reproduzir a condição de corrida onde o servidor envia
// frames binários (renderização) ANTES do handshake de texto (session ID).
#[tokio::test]
async fn test_handshake_arrives_first() {
    // 1. Iniciar Servidor (Mockado ou Real, aqui vamos tentar conectar no real se possível,
    // mas o ideal é subir uma instância isolada).
    // Para simplificar o teste de integração sem mudar a estrutura do main.rs para ser testável,
    // vamos assumir que o usuário rodou ./run.sh OU vamos falhar se não conectar.
    // MELHOR: Vamos replicar a lógica do server::main em menor escala ou conectar no :3000 se já estiver rodando.
    
    let uri = "ws://localhost:3000/ws";
    println!("Connecting to {}", uri);

    // Tenta conectar (assume que o servidor está rodando via ./run.sh)
    let (mut socket, response) = match tokio_tungstenite::connect_async(uri).await {
        Ok(v) => v,
        Err(e) => {
            panic!("Could not connect to server at {}. Is it running? Error: {}", uri, e);
        }
    };

    println!("Connected. HTTP Status: {}", response.status());

    // 2. Ler a PRIMEIRA mensagem
    // O protocolo exige que a primeira mensagem seja TEXTO (JSON com Session ID).
    // Se for BINÁRIO, o teste falha, provando o bug.
    
    use futures::StreamExt;
    
    // Timeout curto pois deve ser imediato
    let first_msg = tokio::time::timeout(Duration::from_secs(2), socket.next()).await;
    
    match first_msg {
        Ok(Some(Ok(msg))) => {
            match msg {
                Message::Text(text) => {
                    println!("SUCCESS: First message is Text: {}", text);
                    assert!(text.contains("WELCOME"), "Text message should contain WELCOME");
                    assert!(text.contains("session_id"), "Text message should contain session_id");
                },
                Message::Binary(bin) => {
                    panic!("FAILURE (BUG REPRODUCED): First message was BINARY ({} bytes). The client JS cannot handle this before the handshake!", bin.len());
                },
                other => panic!("Unexpected message type: {:?}", other),
            }
        },
        Ok(Some(Err(e))) => panic!("Socket error: {}", e),
        Ok(None) => panic!("Socket closed without message"),
        Err(_) => panic!("Timed out waiting for handshake"),
    }
}
