import { client } from "../database/client.js";
import { v4 as uuidv4 } from 'uuid';



export class RouterController {
    static async createRoom(req, res) {
        try {
          console.log("Criando sala");
    
          const username = req.body.username ?? "Gustavo"; // exemplo/placeholder
          const room_uuid = uuidv4();
    
          const roomKey = `room:${room_uuid}`;
          const playersKey = `room:${room_uuid}:players`;
    
          // Metadados da sala (hSet suporta objeto)
          await client.hSet(roomKey, {
            id: room_uuid,
            creator_username: username,
            maxPlayers: String(4),
            status: "open",
            createdAt: String(Date.now())
          });
    
          // adicionar host ao set de players
          await client.sAdd(playersKey, username);
    
          // marcar sala como aberta (set global)
          await client.sAdd("rooms:open", room_uuid);
    
          // indexar por atividade (zAdd recebe array)
          await client.zAdd("rooms:by_activity", [
            { score: Date.now(), value: room_uuid }
          ]);
    
          return res.status(201).send({ room_uuid });
        } catch (err) {
          console.error("createRoom error:", err);
          return res.status(500).send({ error: "failed to create room" });
        }
      }
    
      // Listar salas ativas (retorna metadados e players)
      static async listAllRooms(req, res) {
        try {
          // 1) pegar todos os IDs de salas abertas
          const roomIds = await client.sMembers("rooms:open"); // retorna array de ids
          if (!roomIds || roomIds.length === 0) return res.send({ rooms: [] });
    
          // 2) construir pipeline (multi) para reduzir round-trips
          const multi = client.multi();
          for (const id of roomIds) {
            multi.hGetAll(`room:${id}`);
            multi.sMembers(`room:${id}:players`);
          }
    
          // 3) executar e receber respostas (2 entradas por sala: meta, players)
          const replies = await multi.exec(); // replies é um array de arrays/valores
    
          // 4) montar resultado a partir de replies
          const rooms = [];
          for (let i = 0; i < roomIds.length; i++) {
            const metaReply = replies[i * 2];     // hGetAll result
            const playersReply = replies[i * 2 + 1]; // sMembers result
    
            // normalize meta types (maxPlayers string -> number)
            const meta = metaReply ?? {};
            if (meta && meta.maxPlayers) meta.maxPlayers = Number(meta.maxPlayers);
    
            rooms.push({
              id: roomIds[i],
              meta,
              players: playersReply ?? []
            });
          }
    
          return res.send({ rooms });
        } catch (err) {
          console.error("listAllRooms error:", err);
          return res.status(500).send({ error: "failed to list all rooms", details: String(err) });
        }
      }
      
}