/*
Copyright 2018 Ognjen Orel

This file is part of ifmx utilities.

ifmx utilities is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

IFMX Table copy utility is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with ifmx utilities. If not, see <http://www.gnu.org/licenses/>.
*/

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.*;
import java.awt.*;
import java.util.*;

public class Histogram {
    private static final HashMap<Integer, Integer> freqs = new HashMap<>();

    public static void main(String[] args) throws IOException {

       if (args.length != 2) {
           System.out.println("2 arguments expected: input file, output file");
           return;
       }

       Scanner input = new Scanner(new File(args[0]));

       int value;
       while (input.hasNextInt()) {
           value = input.nextInt();
           freqs.put(value, (freqs.get(value) == null ? 0 : freqs.get(value)) + 1);
       }

       draw(args[1]);
    }

    public static void draw(String outputFileName) throws IOException {
        int width = Math.max(freqs.size() * 6, 100);
        BufferedImage bImg = new BufferedImage(width + 30, 220, BufferedImage.TYPE_INT_ARGB);
        Graphics g = bImg.createGraphics();

        int firstKey = freqs.keySet().iterator().next();
        // frequencies are key occasions
        int max_f = freqs.get(firstKey);
        int min_f = freqs.get(firstKey);
        // values are keys themselves
        int max_v = firstKey;
        int min_v = firstKey;

        for (Integer key : freqs.keySet()) {
            int freq = freqs.get(key);
            if (freq > max_f) max_f = freq;
            if (freq < min_f) min_f = freq;

            if (key > max_v) max_v = key;
            if (key < min_v) min_v = key;
        }

        g.setColor(Color.BLUE);

        for (Integer key : freqs.keySet()) {
            int freq = freqs.get(key);
            // scale to i
            int i = Math.round (((float) key) / max_v * width);

            g.drawLine(i + 6, 190, i + 6, Math.round (190 - ((float) freq)/max_f * 180));

            if (key == min_v) {
                g.drawString(String.valueOf(min_v), i + 3, 210);
            }
            if (key == max_v) {
                g.drawString(String.valueOf(max_v), i + 3, 210);
            }
        }
        g.drawString(String.valueOf(max_f), 0, 15);
        g.drawString(String.valueOf(min_f), 0, 190);

        ImageIO.write(bImg, "png", new File(outputFileName));

    }
}
