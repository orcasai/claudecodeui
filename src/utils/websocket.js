import { useState, useEffect, useRef } from 'react';

export function useWebSocket() {
  const [ws, setWs] = useState(null);
  const [messages, setMessages] = useState([]);
  const [isConnected, setIsConnected] = useState(false);
  const reconnectTimeoutRef = useRef(null);

  useEffect(() => {
    connect();
    
    return () => {
      if (reconnectTimeoutRef.current) {
        clearTimeout(reconnectTimeoutRef.current);
      }
      if (ws) {
        ws.close();
      }
    };
  }, []);

  const connect = async () => {
    try {
      // Get authentication token
      const token = localStorage.getItem('auth-token');
      if (!token) {
        console.warn('No authentication token found for WebSocket connection');
        return;
      }
      
      // Fetch server configuration to get the correct WebSocket URL
      let wsBaseUrl;
      try {
        const configResponse = await fetch('/api/config', {
          headers: {
            'Authorization': `Bearer ${token}`
          }
        });
        
        if (!configResponse.ok) {
          throw new Error(`Config API failed: ${configResponse.status}`);
        }
        
        const config = await configResponse.json();
        wsBaseUrl = config.wsUrl;
        
        console.log('WebSocket config received:', { 
          wsUrl: config.wsUrl, 
          requestHost: config.requestHost,
          currentLocation: window.location.href 
        });
        
        // Additional validation and fallback logic
        if (!wsBaseUrl || wsBaseUrl === 'undefined' || wsBaseUrl.includes('undefined')) {
          throw new Error('Invalid WebSocket URL received from server');
        }
        
        // If we're on a domain but config returns localhost, override with current host
        if (wsBaseUrl.includes('localhost') && !window.location.hostname.includes('localhost')) {
          console.warn('Config returned localhost URL, but we are on domain - constructing WebSocket URL from current location');
          const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
          wsBaseUrl = `${protocol}//${window.location.host}`;
        }
        
      } catch (error) {
        console.warn('Could not fetch server config, constructing WebSocket URL from current location:', error.message);
        const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
        
        // Smart port detection based on current location
        let targetHost = window.location.host;
        
        // If we're on Vite dev server (port 3001), API server is likely on 3002
        if (window.location.port === '3001') {
          const hostname = window.location.hostname;
          targetHost = `${hostname}:3002`;
        }
        // For other cases (including production), use the same host
        
        wsBaseUrl = `${protocol}//${targetHost}`;
        console.log('Fallback WebSocket URL constructed:', wsBaseUrl);
      }
      
      // Include token in WebSocket URL as query parameter
      const wsUrl = `${wsBaseUrl}/ws?token=${encodeURIComponent(token)}`;
      const websocket = new WebSocket(wsUrl);

      websocket.onopen = () => {
        setIsConnected(true);
        setWs(websocket);
      };

      websocket.onmessage = (event) => {
        try {
          const data = JSON.parse(event.data);
          setMessages(prev => [...prev, data]);
        } catch (error) {
          console.error('Error parsing WebSocket message:', error);
        }
      };

      websocket.onclose = () => {
        setIsConnected(false);
        setWs(null);
        
        // Attempt to reconnect after 3 seconds
        reconnectTimeoutRef.current = setTimeout(() => {
          connect();
        }, 3000);
      };

      websocket.onerror = (error) => {
        console.error('WebSocket error:', error);
      };

    } catch (error) {
      console.error('Error creating WebSocket connection:', error);
    }
  };

  const sendMessage = (message) => {
    if (ws && isConnected) {
      ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket not connected');
    }
  };

  return {
    ws,
    sendMessage,
    messages,
    isConnected
  };
}