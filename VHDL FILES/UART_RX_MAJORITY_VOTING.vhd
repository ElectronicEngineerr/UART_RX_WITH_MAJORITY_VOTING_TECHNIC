library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity UART_RX is
    generic (
        CLOCK_FREQ : integer := 100_000_000;
        BAUD_RATE  : integer := 115200
    );
    port (
        CLK          : in  std_logic;
        RX_INPUT     : in  std_logic;
        RX_OUTPUT    : out std_logic_vector(7 downto 0);
        RX_DONE_TICK : out std_logic
    );
end UART_RX;

architecture Behavioral of UART_RX is

    type states is (RX_IDLE_STATE, RX_START_STATE, RX_DATA_RECEIVE_STATE, RX_STOP_STATE);
    signal state : states := RX_IDLE_STATE;

    constant bit_timer_limit : integer := CLOCK_FREQ / BAUD_RATE; 

    signal bit_timer      : integer range 0 to bit_timer_limit := 0;
    signal mv_bit_counter : integer range 0 to 15 := 0;  -- 16 örnek için 0'dan 15'e
    signal bit_counter    : integer range 0 to 7 := 0;    -- 8 data biti okunacak
    signal rx_data_register : std_logic_vector(7 downto 0) := (others => '0'); 
    signal mv_register    : std_logic_vector(15 downto 0) := (others => '0');

begin

    process(CLK)
        variable ones     : integer := 0;
        variable i        : integer;
        variable new_bit  : std_logic;
        variable shift_reg: std_logic_vector(7 downto 0);
    begin
        if rising_edge(CLK) then
            case state is
                when RX_IDLE_STATE =>
                    RX_DONE_TICK <= '0';
                    bit_timer <= 0;
                    if (RX_INPUT = '0') then
                        state <= RX_START_STATE;
                    end if;

                when RX_START_STATE =>
                    -- Start biti için bekleme: Burada start bitin tamamının okunmasını sağlıyoruz
                    if (bit_timer = bit_timer_limit - 1) then
                        state <= RX_DATA_RECEIVE_STATE;
                        bit_timer <= 0;
                    else
                        bit_timer <= bit_timer + 1;
                    end if;

                when RX_DATA_RECEIVE_STATE =>
                    if (bit_counter = 8) then
                        bit_counter <= 0;
                        state <= RX_STOP_STATE;
                    else
                        -- Her 1/16 bit periyodu örnek alınır
                        if (bit_timer = (bit_timer_limit/16) - 1) then
                            bit_timer <= 0;
                            mv_bit_counter <= mv_bit_counter + 1;
                            mv_register <= mv_register(14 downto 0) & RX_INPUT;
                            
                            if (mv_bit_counter = 15) then  -- 16 örnek toplandı
                                mv_bit_counter <= 0;
                                ones := 0;
                                for i in 0 to 15 loop
                                    if (mv_register(i) = '1') then
                                        ones := ones + 1;
                                    end if;
                                end loop;
                                -- Çoğunluk oyu: Örneğin %62.5 (10/16) eşik değeri kullanılmış.
                                if (ones >= 10) then
                                    new_bit := '1';
                                else
                                    new_bit := '0';
                                end if;
                                
                                -- Yeni bit, veri kaydının istenen konumuna ekleniyor.
                                -- Burada MSB'den kaydırma yapılarak yeni bit en üstte yer alıyor.
                                shift_reg := rx_data_register;
                                shift_reg := new_bit & shift_reg(7 downto 1);
                                rx_data_register <= shift_reg;
                                bit_counter <= bit_counter + 1;
                                mv_register <= (others => '0');  -- mv_register sıfırlanıyor
                            end if;
                        else
                            bit_timer <= bit_timer + 1;
                        end if;
                    end if;

                when RX_STOP_STATE =>
                    if (bit_timer = bit_timer_limit - 1) then
                        bit_timer <= 0;
                        RX_DONE_TICK <= '1';
                        state <= RX_IDLE_STATE;
                    else
                        bit_timer <= bit_timer + 1;
                    end if;

                when others =>
                    state <= RX_IDLE_STATE;
            end case;
        end if;
    end process;

    RX_OUTPUT <= rx_data_register;

end Behavioral;
