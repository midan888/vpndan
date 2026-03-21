-- Add Amnezia WireGuard obfuscation parameters to servers table.
-- These are interface-level params shared by all clients connecting to a server.
-- Jc/Jmin/Jmax control junk packet injection; S1/S2 shift header bytes;
-- H1-H4 replace the fixed WireGuard magic type bytes to defeat DPI fingerprinting.

ALTER TABLE servers
    ADD COLUMN IF NOT EXISTS awg_jc    INT NOT NULL DEFAULT 4,
    ADD COLUMN IF NOT EXISTS awg_jmin  INT NOT NULL DEFAULT 40,
    ADD COLUMN IF NOT EXISTS awg_jmax  INT NOT NULL DEFAULT 70,
    ADD COLUMN IF NOT EXISTS awg_s1    INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS awg_s2    INT NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS awg_h1    BIGINT NOT NULL DEFAULT 1928394756,
    ADD COLUMN IF NOT EXISTS awg_h2    BIGINT NOT NULL DEFAULT 3847291056,
    ADD COLUMN IF NOT EXISTS awg_h3    BIGINT NOT NULL DEFAULT 2938475610,
    ADD COLUMN IF NOT EXISTS awg_h4    BIGINT NOT NULL DEFAULT 1029384756;
