import express from "express";
import cors from "cors";
import rooms_router from "./src/routes/room.js";

const app = express();
const port = 3000;

app.use(cors({
    origin: "*",
    methods: ["GET", "POST", "PUT", "DELETE"],
  }));
  
app.use(express.json());

app.use("/rooms", rooms_router);

app.listen(port, () => {
  console.log(`Example app listening on port ${port}`);
});
