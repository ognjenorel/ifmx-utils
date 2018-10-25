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
import java.awt.*;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Scanner;

public class BoxPlot  {

    private static float min, max, q1, median, q3, iqr, lowerLimit, upperLimit;

    private static Float[] data;


    public static void main(String[] args) throws FileNotFoundException {

        if (args.length != 2) {
            System.out.println("2 arguments expected: input file, output file");
            return;
        }

        Scanner input = new Scanner(new File(args[0]));
        ArrayList<Float> list = new ArrayList<>();
        while (input.hasNextFloat()) {
            list.add(input.nextFloat());
        }
        data = new Float[list.size()];
        data = list.toArray(data);

        init();
        draw(args[1]);
    }

    private static void init() {
        int n = data.length;
        Arrays.sort(data);
        q1 = data[n / 4];
        median = data[n / 2];
        q3 = data[3 * n / 4];
        iqr = q3 - q1; // interquartile range
        lowerLimit = q1 - 1.5f * iqr;
        upperLimit = q3 + 1.5f * iqr;
        min = lowerLimit < data[0] ? data[0] : lowerLimit;
        max = upperLimit > data[data.length - 1] ? data[data.length - 1] : upperLimit;
        System.out.println("median = " + median);
    }

    private static void draw(String outputFileName) {
        int min_s, max_s, q1_s, median_s, q3_s; // scaled values
        int width = 400;
        int height = 200;
        int vOffset = 15;
        int hOffset = -15;

        // scale everything to width
        min_s = 0 + vOffset;
        max_s = width + vOffset;
        q1_s = Math.round(q1 / max * width) + vOffset;
        q3_s = Math.round(q3 / max * width)  + vOffset;
        median_s = Math.round(median / max * width) + vOffset;

        BufferedImage bImg = new BufferedImage(width + 30, height, BufferedImage.TYPE_INT_ARGB);
        Graphics g = bImg.createGraphics();

        g.setColor(Color.BLUE);

        g.drawLine(q1_s, height/2 - height/6 + hOffset, q1_s, height/2 + height/6 + hOffset); // q1
        g.drawLine(q3_s, height/2 - height/6 + hOffset, q3_s, height/2 + height/6 + hOffset); // q3
        g.drawLine(median_s, height/2 - height/6 + hOffset, median_s, height/2 + height/6 + hOffset); // median
        g.drawLine(q1_s, height/2 - height/6 + hOffset, q3_s, height/2 - height/6 + hOffset); // upper side of the box
        g.drawLine(q1_s, height/2 + height/6 + hOffset, q3_s, height/2 + height/6 + hOffset); // lower side of the box
        g.drawLine(min_s, height/2 - height/9 + hOffset, min_s, height/2 + height/9 + hOffset); // left whisker
        g.drawLine(min_s, height / 2 + hOffset, q1_s, height / 2 + hOffset); // left whisker stem
        g.drawLine(max_s, height/2 - height/9 + hOffset, max_s, height/2 + height/9 + hOffset); // right whisker
        g.drawLine(q3_s, height / 2 + hOffset, max_s, height / 2 + hOffset); // right whisker stem

        int valuesHeight = height - height/9 + hOffset;
        g.drawString(String.valueOf((int)min), min_s - 10, valuesHeight);
        g.drawString(String.valueOf((int)max), max_s - 10, valuesHeight);
        g.drawString(String.valueOf((int)median), median_s - 10, valuesHeight);
        g.drawString(String.valueOf((int)q1), q1_s - 10, valuesHeight);
        g.drawString(String.valueOf((int)q3), q3_s - 10, valuesHeight);

        try {
            ImageIO.write(bImg, "png", new File(outputFileName));
        } catch (IOException e) {
        }

    }

}
